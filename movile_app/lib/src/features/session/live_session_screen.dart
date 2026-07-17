import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:splitway_core/splitway_core.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:splitway_mobile/l10n/app_localizations.dart';

import '../../config/app_config.dart';
import '../../routing/app_router.dart';
import '../../services/auth/auth_service.dart';
import '../../services/garage/garage_service.dart';
import '../../services/garage/vehicle.dart';
import '../../services/profile/profile_service.dart';
import '../../services/sensors/device_heading_service.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../services/tracking/location_service.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gps_signal_badge.dart';
import '../../shared/widgets/sector_chip.dart';
import '../../shared/widgets/sector_chips_bar.dart';
import '../../shared/widgets/splitway_map.dart';
import '../history/run_comparison.dart';
import '../home/home_shell.dart';
import 'live_session_controller.dart';
import 'session_config_sheet.dart';

String _speedLabel(
  AppLocalizations l,
  AppSettingsController ctrl,
  double mps,
) {
  final v = Formatters.speedMps(mps, unit: ctrl.unitSystem);
  return ctrl.unitSystem == UnitSystem.imperial ? l.unitMph(v) : l.unitKmh(v);
}

String _distanceLabel(
  AppLocalizations l,
  AppSettingsController ctrl,
  double meters,
) {
  final (value, isLarge) = Formatters.distanceMeters(meters, unit: ctrl.unitSystem);
  final formatted = value.toStringAsFixed(value >= 10 ? 1 : 2);
  if (ctrl.unitSystem == UnitSystem.imperial) {
    return isLarge ? l.unitMiles(formatted) : l.unitFeet(formatted);
  }
  return isLarge ? l.unitKilometers(formatted) : l.unitMeters(formatted);
}

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({
    super.key,
    required this.controller,
    required this.config,
    required this.settingsController,
    this.authService,
    this.profileService,
    this.garageService,
  });

  final LiveSessionController controller;
  final AppConfig config;
  final AppSettingsController settingsController;
  final AuthService? authService;
  final ProfileService? profileService;
  final GarageService? garageService;

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen>
    with WidgetsBindingObserver {
  int _lastEventCount = 0;
  int _lastPointCount = 0;
  double? _lastSentBearing;
  AudioPlayer? _audioPlayer;
  final FlyToNotifier _flyToNotifier = FlyToNotifier();
  Timer? _uiTicker;
  bool _followUser = true;
  LiveSessionStage? _prevStage;

  /// Non-admin users don't see the telemetry source picker. We auto-switch
  /// the controller from its `simulated` default to real GPS once, after we
  /// know they're not an admin. Flag prevents the toggle from re-firing if
  /// the user later changes back (which they can't, but defense in depth).
  bool _forcedRealGps = false;

  /// Minimum heading change (degrees) that triggers a new flyTo while the
  /// session is running. Filters out compass micro-jitter.
  static const double _kBearingChangeThresholdDeg = 3.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onChange);
    widget.authService?.addListener(_onChange);
    widget.profileService?.addListener(_onProfileChanged);
    widget.settingsController.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeForceRealGpsForNonAdmin();
    });
    // 1 Hz tick so the lap-elapsed display keeps ticking between GPS samples.
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.controller.stage == LiveSessionStage.running) {
        setState(() {});
      }
    });
    widget.controller.load().then((_) {
      if (!mounted) return;
      if (widget.controller.selectedVehicleId == null) {
        final defaultId = widget.settingsController.defaultVehicleId;
        if (defaultId != null) {
          widget.controller.selectVehicle(defaultId);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onChange);
    widget.authService?.removeListener(_onChange);
    widget.profileService?.removeListener(_onProfileChanged);
    widget.settingsController.removeListener(_onSettingsChanged);
    WakelockPlus.disable().catchError((_) {});
    _uiTicker?.cancel();
    _flyToNotifier.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final ctrl = widget.controller;
      if (ctrl.stage == LiveSessionStage.running &&
          ctrl.source == TrackingSource.realGps &&
          !ctrl.backgroundActive) {
        ctrl.upgradeToBackground();
      }
    }
  }

  /// True when the selected vehicle is motorized — the camera then follows
  /// the GPS course only, ignoring the phone compass/accelerometer.
  bool get _selectedVehicleIsMotorized {
    final id = widget.controller.selectedVehicleId;
    if (id == null) return false;
    for (final v in widget.garageService?.vehicles ?? const <Vehicle>[]) {
      if (v.id == id) return v.type.isMotorized;
    }
    return false;
  }

  void _onMapInteraction() {
    if (_followUser) setState(() => _followUser = false);
  }

  void _centerOnUser() {
    final ctrl = widget.controller;
    setState(() => _followUser = true);
    final ingested = ctrl.tracker?.ingested ?? const [];
    if (ingested.isNotEmpty) {
      _flyToNotifier.flyTo(
        ingested.last.location,
        bearing: ctrl.currentBearingDeg,
        pitch: kNavigationCameraPitchDeg,
      );
    }
  }

  void _onChange() {
    _updateWakelock();
    _onNewEvents();
    final ctrl = widget.controller;
    // Re-enable follow-mode automatically when a new session begins running.
    if (ctrl.stage == LiveSessionStage.running &&
        _prevStage != LiveSessionStage.running &&
        _prevStage != LiveSessionStage.paused) {
      _followUser = true;
    }
    // Show the "session saved" snackbar once when the session finishes —
    // covers both the manual Finish button and the automatic open-route finish.
    if (mounted &&
        ctrl.stage == LiveSessionStage.finished &&
        _prevStage != null &&
        _prevStage != LiveSessionStage.finished &&
        ctrl.result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).sessionSavedSnackBar)),
      );
    }
    // A run that never crossed the start line is discarded (not saved, no
    // results). Surface a brief hint on the running/paused → ready transition
    // so the user understands nothing was recorded.
    if (mounted &&
        ctrl.lastRunDiscarded &&
        (_prevStage == LiveSessionStage.running ||
            _prevStage == LiveSessionStage.paused) &&
        ctrl.stage != LiveSessionStage.running &&
        ctrl.stage != LiveSessionStage.paused) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context).sessionNotStartedSnackBar),
        ),
      );
    }
    _prevStage = ctrl.stage;
    if (ctrl.stage == LiveSessionStage.running && _followUser) {
      final ingested = ctrl.tracker?.ingested ?? const [];
      final bearing = ctrl.currentBearingDeg;
      final pointChanged = ingested.length > _lastPointCount;
      final bearingChanged = bearing != null &&
          (_lastSentBearing == null ||
              angularDifferenceDeg(bearing, _lastSentBearing!).abs() >=
                  _kBearingChangeThresholdDeg);
      if ((pointChanged || bearingChanged) && ingested.isNotEmpty) {
        // Match the user-marker glide (~850 ms) on point changes so the
        // camera and the dot reach the new fix together; keep 300 ms for
        // bearing-only updates so compass rotation stays snappy.
        _flyToNotifier.flyTo(
          ingested.last.location,
          bearing: bearing,
          pitch: kNavigationCameraPitchDeg,
          animationDuration: pointChanged
              ? const Duration(milliseconds: 850)
              : const Duration(milliseconds: 300),
        );
        _lastSentBearing = bearing;
      }
      _lastPointCount = ingested.length;
    }
    setState(() {});
  }

  void _onSettingsChanged() {
    _updateWakelock();
    setState(() {});
  }

  void _onProfileChanged() {
    _maybeForceRealGpsForNonAdmin();
    if (mounted) setState(() {});
  }

  /// If the user is not an admin, switch the controller off `simulated` once
  /// the profile has loaded. Admins keep the toggle; signed-out / signed-in
  /// non-admins go straight to real GPS.
  void _maybeForceRealGpsForNonAdmin() {
    if (_forcedRealGps) return;
    final p = widget.profileService;
    // Profile still loading — wait for the next notify.
    if (p != null && p.loading) return;
    _forcedRealGps = true;
    if (p?.isAdmin == true) return;
    if (widget.controller.source == TrackingSource.simulated) {
      // setSource(realGps) resolves location permission via the geolocator
      // plugin. On real devices this surfaces the permission banner; in
      // widget tests there is no plugin channel, so swallow the error.
      widget.controller.setSource(TrackingSource.realGps).catchError((_) {});
    }
  }

  void _onNewEvents() {
    final tracker = widget.controller.tracker;
    if (tracker == null) return;
    final events = tracker.events;
    if (events.length <= _lastEventCount) return;

    final newEvents = events.sublist(_lastEventCount);
    bool hasCrossing = false;
    for (final evt in newEvents) {
      if (evt is TrackingStarted ||
          evt is SectorCrossed ||
          evt is LapClosed) {
        hasCrossing = true;
        break;
      }
    }
    _lastEventCount = events.length;

    if (hasCrossing) {
      if (widget.settingsController.hapticFeedback) {
        HapticFeedback.mediumImpact();
      }
      if (widget.settingsController.audioAlerts) {
        _audioPlayer ??= AudioPlayer()
          ..setAudioContext(AudioContext(
            android: AudioContextAndroid(
              isSpeakerphoneOn: false,
              audioMode: AndroidAudioMode.normal,
              stayAwake: false,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.assistanceSonification,
              audioFocus: AndroidAudioFocus.none,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.ambient,
              options: {AVAudioSessionOptions.mixWithOthers},
            ),
          ));
        unawaited(_audioPlayer!.play(AssetSource('sounds/beep.mp3')));
      }
    }
  }

  void _updateWakelock() {
    final shouldKeep = widget.settingsController.keepScreenAwake &&
        widget.controller.stage == LiveSessionStage.running;
    WakelockPlus.toggle(enable: shouldKeep).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ctrl = widget.controller;
    final isRunning = ctrl.stage == LiveSessionStage.running ||
        ctrl.stage == LiveSessionStage.paused ||
        ctrl.stage == LiveSessionStage.summary;
    return ListenableBuilder(
      listenable: widget.settingsController,
      builder: (context, _) => Scaffold(
        extendBody: isRunning,
        // During running: no AppBar — the drawer button is inside the map Stack
        // so it is positioned with SafeArea and cannot be obscured by the
        // system status bar.
        appBar: isRunning
            ? null
            : AppBar(
                leading: buildDrawerLeading(
                  context,
                  widget.authService,
                  widget.profileService,
                ),
                title: Text(l.sessionTitle),
              ),
        body: switch (ctrl.stage) {
          LiveSessionStage.selecting => _buildEmpty(context),
          LiveSessionStage.ready => _buildReady(context, ctrl),
          LiveSessionStage.running => _buildRunning(context, ctrl),
          LiveSessionStage.paused => _buildRunning(context, ctrl),
          LiveSessionStage.summary => _buildRunning(context, ctrl),
          LiveSessionStage.finished => _buildFinished(context, ctrl),
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.play_circle_outline,
      title: l.sessionNoRoutesTitle,
      message: l.sessionNoRoutesMessage,
    );
  }

  Widget _buildReady(BuildContext context, LiveSessionController ctrl) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.sessionSelectRoute,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _RoutePickerTile(
            selected: ctrl.selected,
            routes: ctrl.routes,
            onSelected: ctrl.selectRoute,
          ),
          const SizedBox(height: 16),
          if (ctrl.selected != null)
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: SplitwayMap(
                  useMapbox: widget.config.hasMapbox,
                  route: ctrl.selected!,
                  interactive: false,
                ),
              ),
            ),
          if (ctrl.permissionStatus != null) ...[
            const SizedBox(height: 8),
            _PermissionBanner(status: ctrl.permissionStatus!),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: ctrl.selected == null
                ? null
                : () => _openConfigAndStart(ctrl),
            icon: const Icon(Icons.play_arrow),
            label: Text(l.sessionStartButton),
          ),
        ],
      ),
    );
  }

  Future<void> _openConfigAndStart(LiveSessionController ctrl) async {
    final config = await showModalBottomSheet<SessionConfig>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SessionConfigSheet(
        vehicles: widget.garageService?.vehicles ?? const [],
        initialVehicleId: ctrl.selectedVehicleId,
        isAdmin: widget.profileService?.isAdmin == true,
        initialSource: ctrl.source,
        onStart: (c) => Navigator.pop(ctx, c),
      ),
    );
    if (config == null || !mounted) return;

    // Auth guard first: require login before mutating controller state or
    // requesting any OS permission (setSource resolves location permission).
    final allowed = await requireAuth(
      context,
      widget.authService,
      message: AppLocalizations.of(context).loginBannerDefault,
    );
    if (!allowed || !mounted) return;

    // Apply the picked vehicle + source to the controller.
    ctrl.selectVehicle(config.vehicleId);
    if (widget.profileService?.isAdmin == true) {
      await ctrl.setSource(config.source);
      if (!mounted) return;
    }

    var hasBackground = false;
    if (ctrl.source == TrackingSource.realGps) {
      final bgPermission = await LocationService.ensureBackgroundPermission();
      hasBackground = bgPermission == LocationPermissionStatus.granted;
      if (!hasBackground && mounted) {
        final action = await _showBackgroundPermissionDialog(context);
        if (!mounted) return;
        if (action == null || action == true) return;
      }
    }

    if (!mounted) return;
    _lastEventCount = 0;
    // ignore: discarded_futures
    ctrl.startSession(
      distanceFilterMeters: widget.settingsController.gpsSamplingDistanceFilter,
      backgroundActive: hasBackground,
      useCompassHeading: !_selectedVehicleIsMotorized,
      includeHistorical: config.includeHistorical,
      name: config.name,
    );
  }

  bool _simExpanded = false;

  Widget _buildRunning(BuildContext context, LiveSessionController ctrl) {
    final l = AppLocalizations.of(context);
    final tracker = ctrl.tracker!;
    final snapshot = tracker.snapshot;
    final route = ctrl.selected!;
    final theme = Theme.of(context);

    final drawerLeading = buildDrawerLeading(
      context,
      widget.authService,
      widget.profileService,
    );

    // Inset the map below the status bar so Mapbox's compass / attribution
    // badges aren't hidden behind the system UI.
    final topInset = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        Positioned(
          top: topInset,
          left: 0,
          right: 0,
          bottom: 0,
          child: SplitwayMap(
            useMapbox: widget.config.hasMapbox,
            route: route,
            // Estela = solo el tramo de ruta (primer nodo → final). El marcador
            // y la cámara siguen usando ingested.last (posición real).
            telemetry: tracker.trailPoints,
            showSectors: true,
            highlightSectorId: snapshot.lastCrossedSectorId,
            userLocation: tracker.ingested.isNotEmpty
                ? tracker.ingested.last.location
                : null,
            userBearing: ctrl.currentBearingDeg,
            flyToNotifier: _flyToNotifier,
            onUserInteraction: _onMapInteraction,
            persistStyle: true,
            recording: tracker.snapshot.status == TrackingStatus.inLap,
          ),
        ),
        if (drawerLeading != null)
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              right: false,
              child: drawerLeading,
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                if (!ctrl.backgroundActive &&
                    ctrl.source == TrackingSource.realGps) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(l.backgroundDeniedBanner,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: Colors.white)),
                          ),
                          GestureDetector(
                            onTap: () => Geolocator.openAppSettings(),
                            child: Text(l.backgroundOpenSettings,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                )),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Padding(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (ctrl.source == TrackingSource.realGps)
                        GpsSignalBadge(
                          lastPoint: tracker.ingested.isNotEmpty
                              ? tracker.ingested.last
                              : null,
                        ),
                      const Spacer(),
                      FloatingActionButton.small(
                        heroTag: 'live_session_center',
                        onPressed: _centerOnUser,
                        child: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.surface.withValues(alpha: 0.85),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LapIndicators(
                        snapshot: snapshot,
                        isClosed: route.isClosed,
                        settingsController: widget.settingsController,
                        historicalBestLap: ctrl.historicalBestLap,
                        includeHistorical: ctrl.includeHistorical,
                        referenceDuration: ctrl.referenceDuration,
                      ),
                      if (route.sectors.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _LiveSectorChips(
                          route: route,
                          sectorSummaries: tracker.sectorSummaries,
                          currentLap: snapshot.currentLap,
                          historicalRecords: ctrl.historicalSectorRecords,
                        ),
                      ],
                      if (ctrl.source == TrackingSource.simulated) ...[
                        const SizedBox(height: 8),
                        _SimulationToggle(
                          expanded: _simExpanded,
                          onToggle: () =>
                              setState(() => _simExpanded = !_simExpanded),
                          ctrl: ctrl,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _SessionRecordingActions(
                        isPaused: ctrl.stage == LiveSessionStage.paused,
                        onPause: ctrl.pauseSession,
                        onResume: ctrl.resumeSession,
                        onFinish: () async {
                          // The "session saved" snackbar is shown from
                          // _onChange on the running/paused → finished
                          // transition, so it covers both manual and automatic
                          // (open-route) finishes from one place.
                          await ctrl.finishSession();
                        },
                        finishLabel: l.sessionFinishButton,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ),
        if (ctrl.stage == LiveSessionStage.summary && ctrl.result != null)
          _FinishOverlay(
            session: ctrl.result!,
            reference: ctrl.referenceDuration,
            onContinue: ctrl.dismissFinishOverlay,
          ),
      ],
    );
  }

  Future<bool?> _showBackgroundPermissionDialog(BuildContext context) {
    final l = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_on_outlined, size: 32),
        title: Text(l.backgroundDialogTitle),
        content: Text(l.backgroundDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.backgroundDialogSkip),
          ),
          FilledButton(
            onPressed: () {
              Geolocator.openAppSettings();
              Navigator.pop(ctx, true);
            },
            child: Text(l.backgroundDialogOpenSettings),
          ),
        ],
      ),
    );
  }

  Widget _buildFinished(BuildContext context, LiveSessionController ctrl) {
    final l = AppLocalizations.of(context);
    final result = ctrl.result!;
    final route = ctrl.selected!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.sessionCompleteTitle,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(l.sessionRouteLabel(route.name)),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: SplitwayMap(
              useMapbox: widget.config.hasMapbox,
              route: route,
              telemetry: result.points,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _StatsGrid(
          session: result,
          settingsController: widget.settingsController,
        ),
        const SizedBox(height: 16),
        Text(l.sessionLapsLabel,
            style: Theme.of(context).textTheme.titleMedium),
        for (final lap in result.laps)
          ListTile(
            leading: CircleAvatar(child: Text('${lap.lapNumber}')),
            title: Text(Formatters.duration(
              lap.duration,
              dotSeparator: widget.settingsController.timeFormatDot,
            )),
            subtitle: Text(() {
                  final dist = _distanceLabel(l, widget.settingsController, lap.distanceMeters);
                  final speed = _speedLabel(l, widget.settingsController, lap.avgSpeedMps);
                  return '$dist · $speed';
                }()),
            trailing: lap.completed
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.timer_off, color: Colors.orange),
          ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: ctrl.resetForNewSession,
          icon: const Icon(Icons.refresh),
          label: Text(l.sessionNewSessionButton),
        ),
      ],
    );
  }
}

class _SessionRecordingActions extends StatelessWidget {
  const _SessionRecordingActions({
    required this.isPaused,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.finishLabel,
  });

  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final String finishLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!isPaused) {
      return FilledButton.icon(
        onPressed: onPause,
        icon: const Icon(Icons.pause),
        label: Text(l.recordingPauseButton),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.orange.shade700,
          minimumSize: const Size.fromHeight(48),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow),
            label: Text(l.recordingResumeButton),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: onFinish,
            icon: const Icon(Icons.stop),
            label: Text(finishLabel),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ],
    );
  }
}

/// Big lap-time indicators shown in the live panel. On closed circuits it shows
/// the current lap time (left) and the session best lap (right). On open routes
/// (no laps) it shows a single centered elapsed chronometer.
class _LapIndicators extends StatelessWidget {
  const _LapIndicators({
    required this.snapshot,
    required this.isClosed,
    required this.settingsController,
    this.historicalBestLap,
    this.includeHistorical = false,
    this.referenceDuration,
  });

  final TrackingSnapshot snapshot;
  final bool isClosed;
  final AppSettingsController settingsController;
  final Duration? historicalBestLap;
  final bool includeHistorical;
  final Duration? referenceDuration;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final elapsed = Formatters.durationHms(snapshot.currentLapElapsed);
    if (!isClosed) {
      final reference = referenceDuration;
      // No reference available → keep the single centered chronometer.
      if (reference == null) {
        return _BigIndicator(
          label: l.sessionElapsedLabel,
          value: elapsed,
          emphasized: true,
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _BigIndicator(
              label: l.sessionElapsedLabel,
              value: elapsed,
              emphasized: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BigIndicator(
              label: l.sessionTargetLabel,
              value: Formatters.duration(
                reference,
                dotSeparator: settingsController.timeFormatDot,
              ),
              emphasized: false,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      );
    }

    final sessionBest = snapshot.bestLap;
    final histBest = includeHistorical ? historicalBestLap : null;
    // Reference lap = the best of session + historical (when included).
    Duration? reference = sessionBest;
    if (histBest != null) {
      reference = (sessionBest == null || histBest < sessionBest)
          ? histBest
          : sessionBest;
    }
    // Highlight as a record when the reference is the historical best that the
    // session has not beaten yet (consistent with the purple sector tier).
    final isRecordReference = histBest != null &&
        (sessionBest == null || histBest <= sessionBest);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _BigIndicator(
            label: l.sessionCurrentLapLabel,
            value: elapsed,
            emphasized: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BigIndicator(
            label: isRecordReference
                ? l.sessionReferenceLapLabel
                : l.sessionBestLapLabel,
            value: reference == null
                ? l.sessionNoLapYet
                : Formatters.duration(
                    reference,
                    dotSeparator: settingsController.timeFormatDot,
                  ),
            emphasized: false,
            // Reference lap keeps the primary colour whenever one exists (same
            // as the pre-modal best-lap behaviour); the label distinguishes the
            // unbeaten historical record ("to beat") from a session best.
            color: reference == null ? null : theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _BigIndicator extends StatelessWidget {
  const _BigIndicator({
    required this.label,
    required this.value,
    required this.emphasized,
    this.color,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: (emphasized
                  ? theme.textTheme.headlineMedium
                  : theme.textTheme.headlineSmall)
              ?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Row of F1-style sector chips for the current lap. Each sector is grey until
/// it is crossed in the current lap, then coloured by [sectorChipTier] with the
/// crossing time shown below the number.
class _LiveSectorChips extends StatelessWidget {
  const _LiveSectorChips({
    required this.route,
    required this.sectorSummaries,
    required this.currentLap,
    required this.historicalRecords,
  });

  final RouteTemplate route;
  final List<SectorSummary> sectorSummaries;
  final int currentLap;
  final Map<String, Duration> historicalRecords;

  @override
  Widget build(BuildContext context) {
    final sectors = [...route.sectors]
      ..sort((a, b) => a.order.compareTo(b.order));

    // Times for each sector in the current lap (null = not crossed yet).
    final lapTimes = <String, Duration>{};
    // All recorded times per sector across the whole session.
    final sessionTimes = <String, List<Duration>>{};
    for (final s in sectorSummaries) {
      sessionTimes.putIfAbsent(s.sectorId, () => []).add(s.duration);
      if (s.lapNumber == currentLap) lapTimes[s.sectorId] = s.duration;
    }

    // N gates → N+1 sectors: append the implicit final sector (last gate →
    // start/finish), keyed by [kFinalSectorId].
    final sectorIds = [...sectors.map((s) => s.id), kFinalSectorId];

    // First sector without a time this lap = the one in progress; drives the
    // auto-scroll when there are more sectors than fit on screen.
    var activeIndex = sectorIds.length;
    for (var i = 0; i < sectorIds.length; i++) {
      if (lapTimes[sectorIds[i]] == null) {
        activeIndex = i;
        break;
      }
    }

    return SectorChipsBar(
      activeIndex: activeIndex,
      // Show the crossing time below each sector number; sectors not yet
      // crossed this lap stay null (number only).
      times: [for (final id in sectorIds) lapTimes[id]],
      tiers: [
        for (final id in sectorIds)
          sectorChipTier(
            lapTime: lapTimes[id],
            sessionCrossings: sessionTimes[id] ?? const [],
            historicalRecord: historicalRecords[id],
          ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.session,
    required this.settingsController,
  });

  final SessionRun session;
  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final distStr = _distanceLabel(l, settingsController, session.totalDistanceMeters);
    final children = [
      _Stat(l.sessionDistanceLabel, distStr),
      _Stat(l.sessionMaxSpeedLabel, _speedLabel(l, settingsController, session.maxSpeedMps)),
      _Stat(l.sessionAvgSpeedLabel, _speedLabel(l, settingsController, session.avgSpeedMps)),
      _Stat(l.sessionLapsCountLabel, '${session.laps.length}'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        for (final s in children)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.label,
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(s.value,
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat {
  _Stat(this.label, this.value);
  final String label;
  final String value;
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.status});

  final LocationPermissionStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (color, icon, text) = switch (status) {
      LocationPermissionStatus.granted => (
          Colors.green,
          Icons.check_circle_outline,
          l.sessionPermissionGranted,
        ),
      LocationPermissionStatus.denied => (
          Colors.orange,
          Icons.warning_amber_rounded,
          l.sessionPermissionDenied,
        ),
      LocationPermissionStatus.permanentlyDenied => (
          Colors.red,
          Icons.block,
          l.sessionPermissionPermanentlyDenied,
        ),
      LocationPermissionStatus.servicesDisabled => (
          Colors.red,
          Icons.location_off,
          l.sessionServicesDisabled,
        ),
    };
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child:
                Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _SimulationToggle extends StatelessWidget {
  const _SimulationToggle({
    required this.expanded,
    required this.onToggle,
    required this.ctrl,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final LiveSessionController ctrl;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(Icons.science_outlined,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l.sessionSourceSimulated,
                    style: theme.textTheme.titleSmall),
                const Spacer(),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          if (ctrl.isAutoSimulating && ctrl.simTotal > 0) ...[
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: ctrl.simProgress / ctrl.simTotal,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${ctrl.simProgress} / ${ctrl.simTotal}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: ctrl.simulateOnePoint,
                  icon: const Icon(Icons.fast_forward),
                  label: Text(l.sessionSimulatePoint),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: ctrl.toggleAutoSimulate,
                  icon: Icon(ctrl.isAutoSimulating
                      ? Icons.pause
                      : Icons.autorenew),
                  label: Text(ctrl.isAutoSimulating
                      ? l.sessionPauseAuto
                      : l.sessionAutoLap),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(l.sessionSpeedLabel,
                  style: theme.textTheme.labelMedium),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1×')),
                    ButtonSegment(value: 5, label: Text('5×')),
                    ButtonSegment(value: 10, label: Text('10×')),
                  ],
                  selected: {ctrl.simSpeedMultiplier},
                  onSelectionChanged: (s) =>
                      ctrl.setSimSpeedMultiplier(s.first),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Semi-transparent panel shown over the frozen map when an open route finishes.
/// Shows the total time and its delta vs the reference, with a Continue button
/// that advances to the results screen. While it is visible the map + bottom
/// controls are frozen (the session is already finished and saved).
class _FinishOverlay extends StatelessWidget {
  const _FinishOverlay({
    required this.session,
    required this.reference,
    required this.onContinue,
  });

  final SessionRun session;
  final Duration? reference;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = session.totalDuration;
    return Positioned.fill(
      child: GestureDetector(
        // Absorb taps on the backdrop so the frozen controls below stay inert.
        onTap: () {},
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.25),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag, size: 40, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    l.sessionFinishedOverlayTitle,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    total == null ? '--:--' : Formatters.durationHms(total),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (reference != null && total != null) ...[
                    const SizedBox(height: 12),
                    _TimeGainedSummary(expected: reference!, actual: total),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: onContinue,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(l.sessionContinueButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Finish-overlay block that spells out how much time the run gained or lost
/// against the reference: a prominent coloured "{gained/lost} {pct} %" line
/// plus the absolute time delta underneath. Renders nothing when the percentage
/// can't be computed (non-positive reference).
class _TimeGainedSummary extends StatelessWidget {
  const _TimeGainedSummary({required this.expected, required this.actual});

  final Duration expected;
  final Duration actual;

  /// Compact `m:ss` (or `h:mm:ss` past an hour) for the absolute delta, with no
  /// sign — the colour + label already convey gained vs lost.
  static String _compactDelta(Duration d) {
    final abs = d.abs();
    final h = abs.inHours;
    final m = abs.inMinutes.remainder(60);
    final s = abs.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pct = runDeltaPercent(expected: expected, actual: actual);
    if (pct == null) return const SizedBox.shrink();

    final faster = pct < 0;
    final color = faster ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final icon = faster ? Icons.arrow_downward : Icons.arrow_upward;
    final label = faster ? l.sessionTimeGainedLabel : l.sessionTimeLostLabel;
    final pctText = '${pct.abs().toStringAsFixed(0)} %';
    final deltaText = _compactDelta(actual - expected);
    final deltaLine = faster
        ? l.sessionTimeDeltaFaster(deltaText)
        : l.sessionTimeDeltaSlower(deltaText);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 4),
            Text(
              '$label  $pctText',
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          deltaLine,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _RoutePickerTile extends StatelessWidget {
  const _RoutePickerTile({
    required this.selected,
    required this.routes,
    required this.onSelected,
  });

  final RouteTemplate? selected;
  final List<RouteTemplate> routes;
  final ValueChanged<RouteTemplate> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showPicker(context),
      child: InputDecorator(
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected?.name ?? '',
                style: theme.textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<RouteTemplate>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.sessionSelectRoute,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: routes.length,
                itemBuilder: (ctx, i) {
                  final r = routes[i];
                  final isSelected = r.id == selected?.id;
                  return ListTile(
                    title: Text(r.name),
                    subtitle:
                        r.description != null && r.description!.isNotEmpty
                            ? Text(r.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)
                            : null,
                    trailing: isSelected
                        ? Icon(Icons.check,
                            color: Theme.of(ctx).colorScheme.primary)
                        : null,
                    selected: isSelected,
                    onTap: () => Navigator.pop(ctx, r),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) onSelected(picked);
  }
}
