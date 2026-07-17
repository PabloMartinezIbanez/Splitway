// movile_app/lib/src/features/free_ride/free_ride_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:splitway_core/splitway_core.dart';
import 'package:splitway_mobile/l10n/app_localizations.dart';

import '../../config/app_config.dart';
import '../../routing/app_router.dart';
import '../../services/auth/auth_service.dart';
import '../../services/garage/garage_service.dart';
import '../../services/garage/vehicle.dart';
import '../../services/profile/profile_service.dart';
import '../../services/routing/routing_profile.dart';
import '../../services/sensors/device_heading_service.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../services/tracking/location_service.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gps_signal_badge.dart';
import '../../shared/widgets/splitway_map.dart';
import '../../shared/widgets/vehicle_picker_tile.dart';
import '../home/home_shell.dart';
import 'free_ride_controller.dart';

class FreeRideScreen extends StatefulWidget {
  const FreeRideScreen({
    super.key,
    required this.controller,
    required this.config,
    required this.settingsController,
    this.authService,
    this.profileService,
    this.garageService,
  });

  final FreeRideController controller;
  final AppConfig config;
  final AppSettingsController settingsController;
  final AuthService? authService;
  final ProfileService? profileService;
  final GarageService? garageService;

  @override
  State<FreeRideScreen> createState() => _FreeRideScreenState();
}

class _FreeRideScreenState extends State<FreeRideScreen>
    with WidgetsBindingObserver {
  final FlyToNotifier _flyToNotifier = FlyToNotifier();
  bool _followUser = true;
  int _lastPointCount = 0;
  double? _lastSentBearing;
  GeoPoint? _initialCenter;
  Timer? _uiTicker;
  FreeRideStage? _prevStage;

  /// Minimum heading change (degrees) that triggers a new flyTo. Smaller
  /// movements are filtered out so we don't spam the Mapbox channel with
  /// micro-rotations.
  static const double _kBearingChangeThresholdDeg = 3.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onChange);
    widget.settingsController.addListener(_onSettingsChanged);
    // 1 Hz UI tick so the elapsed timer keeps ticking between GPS samples.
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.controller.stage == FreeRideStage.recording) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    widget.settingsController.removeListener(_onSettingsChanged);
    WakelockPlus.disable().catchError((_) {});
    _uiTicker?.cancel();
    _flyToNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final ctrl = widget.controller;
      if (ctrl.stage == FreeRideStage.recording && !ctrl.backgroundActive) {
        ctrl.upgradeToBackground();
      }
    }
  }

  void _onMapInteraction() {
    if (_followUser) setState(() => _followUser = false);
  }

  void _onChange() {
    _updateWakelock();
    final ctrl = widget.controller;
    // Re-enable follow-mode automatically when a new recording begins.
    if (ctrl.stage == FreeRideStage.recording &&
        _prevStage != FreeRideStage.recording &&
        _prevStage != FreeRideStage.paused) {
      _followUser = true;
    }
    _prevStage = ctrl.stage;
    if (ctrl.stage == FreeRideStage.recording && _followUser) {
      final points = ctrl.ingested;
      final bearing = ctrl.currentBearingDeg;
      final pointChanged = points.length > _lastPointCount;
      final bearingChanged = bearing != null &&
          (_lastSentBearing == null ||
              angularDifferenceDeg(bearing, _lastSentBearing!).abs() >=
                  _kBearingChangeThresholdDeg);
      if ((pointChanged || bearingChanged) && points.isNotEmpty) {
        // On point changes, match the user-marker glide so the camera and
        // the dot arrive together; on bearing-only updates stay snappy.
        _flyToNotifier.flyTo(
          points.last.location,
          bearing: bearing,
          pitch: kNavigationCameraPitchDeg,
          animationDuration: pointChanged
              ? const Duration(milliseconds: 850)
              : const Duration(milliseconds: 300),
        );
        _lastSentBearing = bearing;
      }
      _lastPointCount = points.length;
    }
    setState(() {});
  }

  void _onSettingsChanged() {
    _updateWakelock();
    setState(() {});
  }

  void _updateWakelock() {
    final shouldKeep = widget.settingsController.keepScreenAwake &&
        widget.controller.stage == FreeRideStage.recording;
    WakelockPlus.toggle(enable: shouldKeep).catchError((_) {});
  }

  Future<GeoPoint?> _getCurrentLocation() async {
    try {
      final servicesOn = await Geolocator.isLocationServiceEnabled();
      if (!servicesOn) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return GeoPoint(
          latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      return null;
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

  /// Mapbox profile for the currently selected vehicle (null id = on foot).
  String get _selectedRoutingProfile {
    final id = widget.controller.selectedVehicleId;
    if (id == null) return routingProfileForVehicle(null);
    for (final v in widget.garageService?.vehicles ?? const <Vehicle>[]) {
      if (v.id == id) return routingProfileForVehicle(v.type);
    }
    return routingProfileForVehicle(null);
  }

  void _centerOnUser() {
    final ctrl = widget.controller;
    _followUser = true;
    if (ctrl.ingested.isNotEmpty) {
      _flyToNotifier.flyTo(
        ctrl.ingested.last.location,
        bearing: ctrl.currentBearingDeg,
        pitch: kNavigationCameraPitchDeg,
      );
    }
  }

  String _speedLabel(AppLocalizations l, double mps) {
    final v = Formatters.speedMps(mps, unit: widget.settingsController.unitSystem);
    return widget.settingsController.unitSystem == UnitSystem.imperial
        ? l.unitMph(v)
        : l.unitKmh(v);
  }

  String _distanceLabel(AppLocalizations l, double meters) {
    final (value, isLarge) = Formatters.distanceMeters(
      meters,
      unit: widget.settingsController.unitSystem,
    );
    final formatted = value.toStringAsFixed(value >= 10 ? 1 : 2);
    if (widget.settingsController.unitSystem == UnitSystem.imperial) {
      return isLarge ? l.unitMiles(formatted) : l.unitFeet(formatted);
    }
    return isLarge ? l.unitKilometers(formatted) : l.unitMeters(formatted);
  }

  String _elevationLabel(AppLocalizations l, double meters) {
    if (widget.settingsController.unitSystem == UnitSystem.imperial) {
      final feet = meters * 3.28084;
      return l.elevationRangeValueFeet(feet.toStringAsFixed(0));
    }
    return l.elevationRangeValue(meters.toStringAsFixed(0));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ctrl = widget.controller;
    final isRecording = ctrl.stage == FreeRideStage.recording ||
        ctrl.stage == FreeRideStage.paused;
    return ListenableBuilder(
      listenable: widget.settingsController,
      builder: (context, _) => Scaffold(
        extendBody: isRecording,
        // During recording: no AppBar — the drawer button is inside the map Stack
        // so it is positioned with SafeArea and cannot be obscured by the
        // system status bar.
        appBar: isRecording
            ? null
            : AppBar(
                leading: buildDrawerLeading(
                  context,
                  widget.authService,
                  widget.profileService,
                ),
                title: Text(l.freeRideTitle),
              ),
        body: switch (ctrl.stage) {
          FreeRideStage.idle => _buildIdle(context, ctrl),
          FreeRideStage.recording => _buildRecording(context, ctrl),
          FreeRideStage.paused => _buildRecording(context, ctrl),
          FreeRideStage.finished => _buildFinished(context, ctrl),
        },
      ),
    );
  }

  Widget _buildIdle(BuildContext context, FreeRideController ctrl) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmptyState(
            icon: Icons.explore_outlined,
            title: l.freeRideIdleTitle,
            message: l.freeRideIdleMessage,
          ),
          if (ctrl.permissionStatus != null &&
              ctrl.permissionStatus != LocationPermissionStatus.granted) ...[
            const SizedBox(height: 16),
            _PermissionBanner(status: ctrl.permissionStatus!),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final allowed = await requireAuth(
                context,
                widget.authService,
                message: AppLocalizations.of(context).loginBannerDefault,
              );
              if (!allowed || !context.mounted) return;

              // Pre-recording setup: vehicle + optional ride name.
              final confirmed = await _showStartSetupSheet(context, ctrl);
              if (!confirmed || !context.mounted) return;

              // Check background location permission before starting.
              final bgPermission =
                  await LocationService.ensureBackgroundPermission();
              var hasBackground =
                  bgPermission == LocationPermissionStatus.granted;

              if (!hasBackground && context.mounted) {
                final action =
                    await _showBackgroundPermissionDialog(context);
                if (!mounted) return;
                if (action == null || action == true) {
                  // null = dismissed, true = opened settings — don't start.
                  return;
                }
                // action == false → user chose "Skip", start without bg.
              }

              if (!mounted) return;
              _initialCenter = await _getCurrentLocation();
              _followUser = true;
              _lastPointCount = 0;
              await ctrl.startRecording(
                distanceFilterMeters:
                    widget.settingsController.gpsSamplingDistanceFilter,
                backgroundActive: hasBackground,
                useCompassHeading: !_selectedVehicleIsMotorized,
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: Text(l.freeRideStartButton),
          ),
        ],
      ),
    );
  }

  Widget _buildRecording(BuildContext context, FreeRideController ctrl) {
    final l = AppLocalizations.of(context);
    final snap = ctrl.snapshot;
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
            telemetry: ctrl.ingested,
            userLocation: ctrl.ingested.isNotEmpty
                ? ctrl.ingested.last.location
                : null,
            userBearing: ctrl.currentBearingDeg,
            initialCenter: _initialCenter,
            flyToNotifier: _flyToNotifier,
            onUserInteraction: _onMapInteraction,
            persistStyle: true,
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
                if (!ctrl.backgroundActive) ...[
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
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GpsSignalBadge(
                        lastPoint: ctrl.ingested.isNotEmpty
                            ? ctrl.ingested.last
                            : null,
                      ),
                      const Spacer(),
                      FloatingActionButton.small(
                        heroTag: 'free_ride_center',
                        onPressed: _centerOnUser,
                        child: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.85),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
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
                      Row(
                        children: [
                          Expanded(
                            child: _CompactMetric(
                              label: l.freeRideElapsedLabel,
                              value: Formatters.durationHms(ctrl.currentElapsed),
                            ),
                          ),
                          Expanded(
                            child: _CompactMetric(
                              label: l.freeRideDistanceLabel,
                              value: _distanceLabel(
                                  l, snap.totalDistanceMeters),
                            ),
                          ),
                          Expanded(
                            child: _CompactMetric(
                              label: l.freeRideSpeedLabel,
                              value: _speedLabel(l, snap.currentSpeedMps),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _RecordingActions(
                        isPaused: ctrl.stage == FreeRideStage.paused,
                        onPause: ctrl.pauseRecording,
                        onResume: ctrl.resumeRecording,
                        onFinish: () async {
                          final savedText = l.freeRideSavedSnackBar;
                          final messenger = ScaffoldMessenger.of(context);
                          await ctrl.finishRecording(
                            routingProfile: _selectedRoutingProfile,
                          );
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text(savedText)),
                          );
                        },
                        finishLabel: l.freeRideFinishButton,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ),
      ],
    );
  }

  Widget _buildFinished(BuildContext context, FreeRideController ctrl) {
    final l = AppLocalizations.of(context);
    final result = ctrl.result!;
    final distStr = _distanceLabel(l, result.totalDistanceMeters);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.freeRideCompleteTitle,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: SplitwayMap(
              useMapbox: widget.config.hasMapbox,
              telemetry: result.points,
              interactive: false,
              finishMarker: result.points.isNotEmpty
                  ? result.points.last.location
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(l.freeRideDistanceLabel, distStr),
            ),
            Expanded(
              child: _StatCard(
                l.freeRideMaxSpeedLabel,
                _speedLabel(l, result.maxSpeedMps),
              ),
            ),
            Expanded(
              child: _StatCard(
                l.freeRideAvgSpeedLabel,
                _speedLabel(l, result.avgSpeedMps),
              ),
            ),
          ],
        ),
        if (result.elevationRangeMeters != null) ...[
          const SizedBox(height: 8),
          _StatCard(
            l.elevationRangeLabel,
            _elevationLabel(l, result.elevationRangeMeters!),
          ),
        ],
        if (result.totalDuration != null) ...[
          const SizedBox(height: 8),
          _StatCard(
            l.freeRideElapsedLabel,
            Formatters.duration(
              result.totalDuration!,
              dotSeparator: widget.settingsController.timeFormatDot,
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _showSaveAsRouteDialog(context, ctrl),
          icon: const Icon(Icons.save_alt),
          label: Text(l.freeRideSaveAsRouteButton),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: ctrl.resetForNewRide,
          icon: const Icon(Icons.refresh),
          label: Text(l.freeRideNewRideButton),
        ),
      ],
    );
  }

  /// Pre-recording setup sheet: lets the user pick the vehicle and give the
  /// ride an optional name (pre-filled with the default label it would get).
  /// Returns `true` when the user confirmed and recording should start.
  Future<bool> _showStartSetupSheet(
    BuildContext context,
    FreeRideController ctrl,
  ) async {
    final l = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: l.historyFreeRideLabel);
    final vehicles = widget.garageService?.vehicles ?? const <Vehicle>[];
    var vehicleId = ctrl.selectedVehicleId;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final cs = Theme.of(ctx).colorScheme;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.play_arrow_rounded,
                          color: cs.onPrimaryContainer, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        l.freeRideSetupTitle,
                        style: Theme.of(ctx)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (vehicles.isNotEmpty) ...[
                  Text(
                    l.vehiclePickerLabel,
                    style: Theme.of(ctx)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  VehiclePickerTile(
                    selectedVehicleId: vehicleId,
                    vehicles: vehicles,
                    onSelected: (id) => setSheetState(() => vehicleId = id),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l.freeRideSetupNameLabel,
                    prefixIcon: const Icon(Icons.label_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => Navigator.pop(ctx, true),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(l.commonCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l.freeRideStartButton),
                        style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );

    if (confirmed != true) return false;
    ctrl.selectVehicle(vehicleId);
    ctrl.setSessionName(nameCtrl.text);
    return true;
  }

  /// Shows a dialog explaining that background location permission is needed
  /// and offering to open settings or continue without it.
  /// Returns `true` if the user chose to open settings, `false` if they chose
  /// to skip, and `null` if they dismissed the dialog.
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

  Future<void> _showSaveAsRouteDialog(
    BuildContext context,
    FreeRideController ctrl,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var difficulty = RouteDifficulty.medium;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cs = Theme.of(ctx).colorScheme;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.save_rounded,
                          color: cs.onPrimaryContainer, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        l.freeRideSaveRouteDialogTitle,
                        style: Theme.of(ctx)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l.freeRideNameLabel,
                    prefixIcon: const Icon(Icons.label_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: l.freeRideDescriptionLabel,
                    prefixIcon: const Icon(Icons.notes_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                Text(
                  l.freeRideDifficultyLabel,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _FreeRideDifficultySelector(
                  value: difficulty,
                  onChanged: (d) => setDialogState(() => difficulty = d),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(l.commonCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(l.commonSave),
                        style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final route = await ctrl.saveAsRoute(
      name: name,
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      difficulty: difficulty,
    );

    if (!mounted || route == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l.freeRideRouteSavedSnack(route.name))),
    );
    ctrl.resetForNewRide();
  }
}

class _RecordingActions extends StatelessWidget {
  const _RecordingActions({
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

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.status});

  final LocationPermissionStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _FreeRideDifficultySelector extends StatelessWidget {
  const _FreeRideDifficultySelector({
    required this.value,
    required this.onChanged,
  });

  final RouteDifficulty value;
  final ValueChanged<RouteDifficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        _buildOption(
          context: context,
          difficulty: RouteDifficulty.easy,
          label: l.editorDifficultyEasy,
          icon: Icons.park_rounded,
          color: Colors.green,
        ),
        const SizedBox(width: 10),
        _buildOption(
          context: context,
          difficulty: RouteDifficulty.medium,
          label: l.editorDifficultyMedium,
          icon: Icons.terrain_rounded,
          color: Colors.orange,
        ),
        const SizedBox(width: 10),
        _buildOption(
          context: context,
          difficulty: RouteDifficulty.hard,
          label: l.editorDifficultyHard,
          icon: Icons.whatshot_rounded,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required RouteDifficulty difficulty,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final selected = value == difficulty;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(difficulty),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : cs.surfaceContainerHighest.withValues(alpha: 0.4),
            border: Border.all(
              color: selected ? color : cs.outline.withValues(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? color : cs.onSurfaceVariant, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? color : cs.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
