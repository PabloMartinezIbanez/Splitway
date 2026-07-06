import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:splitway_core/splitway_core.dart';
import 'package:splitway_mobile/l10n/app_localizations.dart';

import '../../config/app_config.dart';
import '../../routing/app_router.dart';
import '../../services/auth/auth_service.dart';
import '../../services/profile/profile_service.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../services/tracking/location_service.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/splitway_map.dart';
import '../home/home_shell.dart';
import 'route_detail_screen.dart';
import 'route_editor_controller.dart';
import 'widgets/difficulty_selector.dart';
import 'widgets/location_search_bar.dart';
import 'widgets/route_grid_tile.dart';
import 'widgets/route_list_tile.dart';

class RouteEditorScreen extends StatefulWidget {
  const RouteEditorScreen({
    super.key,
    required this.controller,
    required this.config,
    this.authService,
    this.profileService,
    this.settingsController,
  });

  final RouteEditorController controller;
  final AppConfig config;
  final AuthService? authService;
  final ProfileService? profileService;
  final AppSettingsController? settingsController;

  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

enum _ViewMode { list, grid }

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  _ViewMode _viewMode = _ViewMode.list;
  GeoPoint? _userLocation;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    widget.authService?.addListener(_onChange);
    widget.profileService?.addListener(_onChange);
    widget.controller.load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    widget.authService?.removeListener(_onChange);
    widget.profileService?.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    // Defer setState to avoid calling it during the build phase when a
    // ChangeNotifier fires while the widget tree is still being built.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      if (mounted) setState(() {});
    }
  }

  Future<void> _onCreateRoute() async {
    // Auth guard: require login before creating a new route.
    final allowed = await requireAuth(
      context,
      widget.authService,
      message: AppLocalizations.of(context).loginBannerDefault,
    );
    if (!allowed || !mounted) return;

    final result = await showModalBottomSheet<_NewRouteResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _NewRouteSheet(),
    );
    if (result == null) return;

    // Try to get the user's current location for the initial map center.
    _userLocation = await _getCurrentLocation();

    widget.controller.startDrawing(
      name: result.name,
      description: result.description,
      difficulty: result.difficulty,
    );
  }

  /// Returns the user's current GPS position, or null if unavailable.
  /// Uses a 5-second timeout to avoid blocking the UI.
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
      return GeoPoint(latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ctrl = widget.controller;
    if (ctrl.drawing) {
      return _DrawingView(
        controller: ctrl,
        config: widget.config,
        initialCenter: _userLocation,
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: buildDrawerLeading(
          context,
          widget.authService,
          widget.profileService,
        ),
        title: Text(l.routesTitle),
        actions: [
          IconButton(
            tooltip: _viewMode == _ViewMode.list
                ? l.routesViewGrid
                : l.routesViewList,
            onPressed: () => setState(() {
              _viewMode = _viewMode == _ViewMode.list
                  ? _ViewMode.grid
                  : _ViewMode.list;
            }),
            icon: Icon(
              _viewMode == _ViewMode.list
                  ? Icons.grid_view_rounded
                  : Icons.view_list_rounded,
            ),
          ),
          IconButton(
            tooltip: l.editorNewRouteTooltip,
            onPressed: _onCreateRoute,
            icon: const Icon(Icons.add_location_alt_outlined),
          ),
        ],
      ),
      body: ctrl.loading
          ? const Center(child: CircularProgressIndicator())
          : ctrl.routes.isEmpty
              ? EmptyState(
                  icon: Icons.route_outlined,
                  title: l.editorNoRoutesTitle,
                  message: l.editorNoRoutesMessage,
                  action: FilledButton.icon(
                    onPressed: _onCreateRoute,
                    icon: const Icon(Icons.add),
                    label: Text(l.editorNewRouteButton),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshOfficialCatalog,
                  child: _viewMode == _ViewMode.list
                      ? _buildListView(ctrl)
                      : _buildGridView(ctrl),
                ),
    );
  }

  /// Pull-to-refresh callback: re-fetch the official catalog from Supabase
  /// and reconcile with local state. Returns a Future the indicator awaits.
  Future<void> _refreshOfficialCatalog() async {
    final svc = widget.controller.officialRoutesService;
    if (svc == null) return;
    await svc.refresh();
  }

  Widget _buildListView(RouteEditorController ctrl) {
    return ListView.separated(
      // AlwaysScrollableScrollPhysics so the pull gesture works even when the
      // list is too short to overscroll on its own.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: ctrl.routes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final route = ctrl.routes[index];
        return RouteListTile(
          route: route,
          sessionCount: ctrl.routeSessionCounts[route.id] ?? 0,
          bestLap: ctrl.routeBestLaps[route.id],
          onTap: () => _openRouteDetail(route),
          settingsController: widget.settingsController,
        );
      },
    );
  }

  Widget _buildGridView(RouteEditorController ctrl) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: ctrl.routes.length,
      itemBuilder: (_, index) {
        final route = ctrl.routes[index];
        return RouteGridTile(
          route: route,
          sessionCount: ctrl.routeSessionCounts[route.id] ?? 0,
          bestLap: ctrl.routeBestLaps[route.id],
          onTap: () => _openRouteDetail(route),
          settingsController: widget.settingsController,
        );
      },
    );
  }

  void _openRouteDetail(RouteTemplate route) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RouteDetailScreen(
        route: route,
        controller: widget.controller,
        config: widget.config,
        settingsController: widget.settingsController,
      ),
    ));
  }
}

class _DrawingView extends StatefulWidget {
  const _DrawingView({
    required this.controller,
    required this.config,
    this.initialCenter,
  });

  final RouteEditorController controller;
  final AppConfig config;
  final GeoPoint? initialCenter;

  @override
  State<_DrawingView> createState() => _DrawingViewState();
}

class _DrawingViewState extends State<_DrawingView> {
  final FlyToNotifier _flyToNotifier = FlyToNotifier();
  StreamSubscription<TelemetryPoint>? _locationSub;
  GeoPoint? _liveLocation;

  @override
  void initState() {
    super.initState();
    _startLocationStream();
  }

  void _startLocationStream() {
    _locationSub = LocationService.positionStream(
      distanceFilterMeters: 3,
    ).listen(
      (tp) => setState(() => _liveLocation = tp.location),
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _flyToNotifier.dispose();
    super.dispose();
  }

  void _centerOnUser() {
    final loc = _liveLocation;
    if (loc != null) {
      _flyToNotifier.flyTo(loc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.editorDrawingTitle(controller.draftName)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l.editorCancelTooltip,
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(l.editorCancelDrawingTitle),
                content: Text(l.editorCancelDrawingWarning),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(l.commonBack),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(l.commonDiscard),
                  ),
                ],
              ),
            );
            if (ok == true) controller.cancelDrawing();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: l.editorUndoPoint,
            onPressed:
                controller.canUndo ? controller.undoLastAction : null,
          ),
          if (controller.snapping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: controller.draftCanSave
                  ? () async {
                      final saved = await controller.saveDraft();
                      if (!context.mounted) return;
                      if (saved != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text(l.editorRouteSavedSnack(saved.name)),
                          ),
                        );
                      }
                    }
                  : null,
              child: Text(l.commonSave),
            ),
        ],
      ),
      body: Stack(
        children: [
          SplitwayMap(
            useMapbox: widget.config.hasMapbox,
            initialCenter: widget.initialCenter,
            flyToNotifier: _flyToNotifier,
            draftPath: controller.draftPath,
            draftWaypoints: controller.rawWaypoints,
            draftSectorPoints: controller.draftSectorPoints,
            userLocation: _liveLocation,
            onTap: controller.handleMapTap,
            freehandMode:
                controller.inputMode == DrawInputMode.freehand,
            draftSegments: controller.segments,
            onFreehandStart: controller.startFreehandStroke,
            onFreehandPoint: controller.addFreehandPoint,
            onFreehandEnd: controller.endFreehandStroke,
          ),
          if (widget.config.hasMapbox)
            Positioned(
              top: 8,
              left: 12,
              right: 56,
              child: SafeArea(
                child: LocationSearchBar(
                  accessToken: widget.config.mapboxToken!,
                  onLocationSelected: (point) =>
                      _flyToNotifier.flyTo(point),
                ),
              ),
            ),
          if (!widget.config.hasMapbox)
            Positioned(
              left: 0,
              right: 0,
              bottom: 64,
              child: _InfoBanner(
                color: theme.colorScheme.tertiaryContainer,
                icon: Icons.map_outlined,
                message: l.editorNoMapboxToken,
              ),
            )
          else if (controller.snapFailed)
            Positioned(
              left: 0,
              right: 0,
              bottom: 64,
              child: _InfoBanner(
                color: theme.colorScheme.errorContainer,
                icon: controller.snapRateLimited
                    ? Icons.hourglass_top_outlined
                    : Icons.wifi_off_outlined,
                iconColor: theme.colorScheme.onErrorContainer,
                message: controller.snapRateLimited
                    ? l.editorSnapRateLimitedMessage
                    : l.editorSnapFailedMessage,
                textColor: theme.colorScheme.onErrorContainer,
              ),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DrawingModeFab(
                  mode: controller.inputMode,
                  onChanged: controller.setInputMode,
                ),
                const SizedBox(width: 12),
                _RoutingProfileFab(
                  profile: controller.routingProfile,
                  onChanged: (p) => controller.routingProfile = p,
                ),
                const SizedBox(width: 12),
                FloatingActionButton.small(
                  heroTag: 'center_on_user',
                  onPressed: _centerOnUser,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawingModeFab extends StatelessWidget {
  const _DrawingModeFab({
    required this.mode,
    required this.onChanged,
  });

  final DrawInputMode mode;
  final ValueChanged<DrawInputMode> onChanged;

  static const _modes = [
    (DrawInputMode.appendPath, Icons.timeline),
    (DrawInputMode.sectorPoint, Icons.flag),
    (DrawInputMode.freehand, Icons.gesture),
  ];

  IconData get _activeIcon =>
      _modes.firstWhere((m) => m.$1 == mode).$2;

  String _label(AppLocalizations l, DrawInputMode m) => switch (m) {
        DrawInputMode.appendPath => l.editorSegmentPath,
        DrawInputMode.sectorPoint => l.editorSegmentAddSector,
        DrawInputMode.freehand => l.editorSegmentFreehand,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return PopupMenuButton<DrawInputMode>(
      onSelected: onChanged,
      tooltip: l.editorDrawingModeTooltip,
      position: PopupMenuPosition.over,
      offset: const Offset(0, -160),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        for (final (key, icon) in _modes)
          PopupMenuItem<DrawInputMode>(
            value: key,
            child: Row(
              children: [
                Icon(icon,
                    color: key == mode
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: Text(_label(l, key))),
                if (key == mode)
                  Icon(Icons.check,
                      size: 18, color: theme.colorScheme.primary),
              ],
            ),
          ),
      ],
      child: FloatingActionButton.small(
        heroTag: 'drawing_mode',
        onPressed: null,
        backgroundColor: theme.colorScheme.primaryContainer,
        child:
            Icon(_activeIcon, color: theme.colorScheme.onPrimaryContainer),
      ),
    );
  }
}

/// A full-width informational/warning banner shown below the map.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.color,
    required this.icon,
    required this.message,
    this.iconColor,
    this.textColor,
  });

  final Color color;
  final IconData icon;
  final String message;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor =
        iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final effectiveTextColor =
        textColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: effectiveIconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: effectiveTextColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutingProfileFab extends StatelessWidget {
  const _RoutingProfileFab({
    required this.profile,
    required this.onChanged,
  });

  final String profile;
  final ValueChanged<String> onChanged;

  static const _profiles = [
    ('driving', Icons.directions_car),
    ('walking', Icons.directions_walk),
    ('cycling', Icons.directions_bike),
  ];

  IconData get _activeIcon =>
      _profiles.firstWhere((p) => p.$1 == profile).$2;

  String _label(AppLocalizations l, String key) => switch (key) {
        'driving' => l.editorRoutingProfileDriving,
        'walking' => l.editorRoutingProfileWalking,
        'cycling' => l.editorRoutingProfileCycling,
        _ => key,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      onSelected: onChanged,
      tooltip: l.editorRoutingProfileTooltip,
      position: PopupMenuPosition.over,
      offset: const Offset(0, -160),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        for (final (key, icon) in _profiles)
          PopupMenuItem<String>(
            value: key,
            child: Row(
              children: [
                Icon(icon, color: key == profile
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: Text(_label(l, key))),
                if (key == profile)
                  Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
              ],
            ),
          ),
      ],
      child: FloatingActionButton.small(
        heroTag: 'routing_profile',
        onPressed: null,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(_activeIcon, color: theme.colorScheme.onPrimaryContainer),
      ),
    );
  }
}

class _NewRouteResult {
  _NewRouteResult({
    required this.name,
    required this.difficulty,
    this.description,
  });

  final String name;
  final String? description;
  final RouteDifficulty difficulty;
}

class _NewRouteSheet extends StatefulWidget {
  const _NewRouteSheet();

  @override
  State<_NewRouteSheet> createState() => _NewRouteSheetState();
}

class _NewRouteSheetState extends State<_NewRouteSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  RouteDifficulty _difficulty = RouteDifficulty.medium;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
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
                child: Icon(Icons.route_rounded, color: cs.onPrimaryContainer, size: 24),
              ),
              const SizedBox(width: 14),
              Text(
                l.editorNewRouteDialogTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: l.editorNameLabel,
              prefixIcon: const Icon(Icons.label_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            decoration: InputDecoration(
              labelText: l.editorDescriptionLabel,
              prefixIcon: const Icon(Icons.notes_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l.editorDifficultyLabel,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          DifficultySelector(
            value: _difficulty,
            onChanged: (d) => setState(() => _difficulty = d),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                  onPressed: () {
                    final name = _nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(
                      context,
                      _NewRouteResult(
                        name: name,
                        difficulty: _difficulty,
                        description: _descCtrl.text.trim().isEmpty
                            ? null
                            : _descCtrl.text.trim(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.draw_rounded),
                  label: Text(l.editorStartDrawingButton),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
  }
}

