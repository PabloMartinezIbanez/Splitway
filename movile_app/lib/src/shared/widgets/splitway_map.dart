import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart' show PlatformException;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitway_core/splitway_core.dart';
import 'package:splitway_mobile/l10n/app_localizations.dart';

import '../../features/editor/draft_segment.dart';
import '../../services/settings/app_settings_controller.dart';
import '../speed_palette.dart';
import 'route_map_painter.dart';
import 'sector_segments.dart';

enum MapStyle {
  outdoors,
  satelliteStreets,
  dark;

  String get uri => switch (this) {
        MapStyle.outdoors => mbx.MapboxStyles.OUTDOORS,
        MapStyle.satelliteStreets => mbx.MapboxStyles.SATELLITE_STREETS,
        MapStyle.dark => mbx.MapboxStyles.DARK,
      };

  IconData get icon => switch (this) {
        MapStyle.outdoors => Icons.terrain,
        MapStyle.satelliteStreets => Icons.satellite_alt,
        MapStyle.dark => Icons.dark_mode,
      };

  String label(AppLocalizations l) => switch (this) {
        MapStyle.outdoors => l.mapStyleOutdoors,
        MapStyle.satelliteStreets => l.mapStyleSatelliteStreets,
        MapStyle.dark => l.mapStyleDark,
      };
}

const _kMapStyleKey = 'splitway_map_style';

/// Camera tilt used while recording so the map shows what's ahead instead of
/// a top-down view, mirroring Google Maps' navigation perspective.
const double kNavigationCameraPitchDeg = 45.0;

/// A notifier that always fires, even when set to the same value.
/// [ValueNotifier] silently ignores duplicate values, which breaks
/// "center on me" buttons that re-fly to the current position.
class FlyToNotifier extends ChangeNotifier {
  GeoPoint? _target;
  GeoPoint? get target => _target;

  double? _bearing;
  double? get bearing => _bearing;

  double? _pitch;
  double? get pitch => _pitch;

  Duration _animationDuration = const Duration(milliseconds: 800);
  Duration get animationDuration => _animationDuration;

  void flyTo(
    GeoPoint point, {
    double? bearing,
    double? pitch,
    Duration animationDuration = const Duration(milliseconds: 800),
  }) {
    _target = point;
    _bearing = bearing;
    _pitch = pitch;
    _animationDuration = animationDuration;
    notifyListeners();
  }
}

/// Wraps a real Mapbox `MapWidget` when [useMapbox] is true; otherwise falls
/// back to the iter 1 `RouteMapPainter`. The fallback keeps widget tests
/// working (no Mapbox SDK in test env) and lets the app boot without a
/// token configured.
///
/// Tap/long-press are reported with a [GeoPoint] in WGS84 (lat/lng).
class SplitwayMap extends StatefulWidget {
  const SplitwayMap({
    super.key,
    required this.useMapbox,
    this.route,
    this.telemetry = const [],
    this.draftPath = const [],
    this.draftWaypoints = const [],
    this.draftSectorPoints = const [],
    this.highlightSectorId,
    this.showSectors = false,
    this.userLocation,
    this.userBearing,
    this.initialCenter,
    this.flyToNotifier,
    this.onTap,
    this.onLongPress,
    this.styleUri,
    this.interactive = true,
    this.freehandMode = false,
    this.draftSegments = const [],
    this.onFreehandStart,
    this.onFreehandPoint,
    this.onFreehandEnd,
    this.showSpeedHeatmap = false,
    this.speedHeatmapUnit = UnitSystem.metric,
    this.onUserInteraction,
    this.finishMarker,
    this.persistStyle = false,
    this.recording = true,
  });

  final bool useMapbox;
  final RouteTemplate? route;
  final List<TelemetryPoint> telemetry;
  /// Road-snapped polyline shown during drawing (may have thousands of points).
  final List<GeoPoint> draftPath;
  /// User-tapped waypoints shown as circles during drawing (typically < 25).
  final List<GeoPoint> draftWaypoints;
  /// Snapped path vertices marking sector boundaries (shown as circles while drawing).
  final List<GeoPoint> draftSectorPoints;
  final String? highlightSectorId;
  /// When true, the saved route is drawn in per-sector colors instead of solid blue.
  final bool showSectors;
  /// Current user position shown as a blue dot on the map.
  final GeoPoint? userLocation;
  /// Current heading of the user in degrees (0 = north, clockwise). When
  /// non-null the user marker is drawn as a directional arrow pointing this
  /// way; when null it falls back to a plain blue circle (direction unknown).
  final double? userBearing;
  /// Initial camera center (e.g. user GPS location). Falls back to Madrid if null.
  final GeoPoint? initialCenter;
  /// When this notifier fires, the map flies to the given point.
  final FlyToNotifier? flyToNotifier;
  final ValueChanged<GeoPoint>? onTap;
  final ValueChanged<GeoPoint>? onLongPress;
  final String? styleUri;
  final bool interactive;
  final bool freehandMode;
  final List<DraftSegment> draftSegments;
  final VoidCallback? onFreehandStart;
  final ValueChanged<GeoPoint>? onFreehandPoint;
  final VoidCallback? onFreehandEnd;
  /// When true, the telemetry line is rendered with a continuous speed
  /// heatmap (and the planned-route line is hidden). Requires telemetry
  /// points with `speedMps`.
  final bool showSpeedHeatmap;
  /// Unit used to compute the heatmap legend's "nice" max bucket.
  final UnitSystem speedHeatmapUnit;
  /// Called when the user touches the map (pan, zoom, tap). Use to disable
  /// GPS-follow mode until the center-on-user button is pressed again.
  final VoidCallback? onUserInteraction;
  /// Position of the checkered finish flag when there is no [route] (e.g. a
  /// finished free ride: pass the last telemetry point). Ignored when [route]
  /// is set, where the flag is drawn at the route's last path node. Like the route
  /// flag, it is hidden while the speed heatmap is active.
  final GeoPoint? finishMarker;
  /// When true, the map restores the user's last-selected style from
  /// SharedPreferences on launch and persists changes made via the switcher.
  /// Only the live recording maps (route session, free ride) set this; every
  /// other map (previews, editor, result review) starts on the classic
  /// Outdoors style and any ad-hoc style change there is session-local.
  final bool persistStyle;

  /// When false, the recorded trail is drawn fully static and its final segment
  /// does NOT grow toward [userLocation]. The live session sets this false once
  /// the route has finished so the estela freezes at the last in-route point
  /// even if late GPS samples keep updating the user marker. Defaults to true
  /// (every other caller keeps the previous growing-tip behaviour).
  final bool recording;

  @override
  State<SplitwayMap> createState() => _SplitwayMapState();
}

const String _kHeatmapSourceId = 'splitway-speed-src';
const String _kHeatmapLayerId = 'splitway-speed-layer';

/// Duration of the smooth glide applied to the user-location dot between two
/// consecutive GPS samples. Chosen to roughly match a 1 Hz sample cadence so
/// the marker reaches its target just as the next fix arrives, mirroring
/// Google Maps' navigation feel.
const Duration _kUserMarkerGlideDuration = Duration(milliseconds: 850);

class _SplitwayMapState extends State<SplitwayMap>
    with SingleTickerProviderStateMixin {
  mbx.MapboxMap? _map;
  mbx.PolylineAnnotationManager? _lineManager;
  mbx.CircleAnnotationManager? _circleManager;
  final _activePointers = <int>{};
  bool _isFreehandStrokeActive = false;
  bool _isRendering = false;
  bool _renderPending = false;
  MapStyle _mapStyle = MapStyle.outdoors;
  // The style URI currently loaded on the *native* map. The native view is
  // always created with the default style — the persisted style is read
  // asynchronously and only lands after the first frame — so this lets us
  // reconcile the rendered style with [_mapStyle] (the value the switcher
  // shows as selected) once both the prefs read and the map are ready.
  String? _activeStyleUri;
  bool _applyingStyle = false;
  bool _applyStylePending = false;

  // Smooth user-location marker animation: interpolates between the previous
  // visible position and the latest GPS fix instead of teleporting on every
  // sample.
  late final AnimationController _userMarkerAnim;
  GeoPoint? _markerStart;
  GeoPoint? _markerEnd;
  GeoPoint? _animatedUserLocation;
  mbx.CircleAnnotation? _userCircleAnnotation;
  bool _userMarkerUpdateInFlight = false;
  bool _userMarkerUpdatePending = false;

  // Directional user marker. When the heading is known the marker switches
  // from the circle to a rotatable arrow rendered on a dedicated point
  // manager (symbols can rotate; circles can't).
  mbx.PointAnnotationManager? _arrowManager;
  mbx.PointAnnotation? _userArrowAnnotation;
  double? _userBearing;
  Uint8List? _arrowImageBytes;
  double _arrowDpr = 3.0;

  // Finish-line marker rendered at the start/finish gate center.
  mbx.PointAnnotationManager? _finishMarkerManager;
  Uint8List? _finishFlagImageBytes;

  // Smooth growth of the recorded track. The bulk of the line (every
  // confirmed point except the newest) is drawn once per GPS sample like
  // before; the final, moving segment is a cheap 2-point "tip" that glides
  // toward the latest fix at the same pace as the user marker, so the line
  // extends smoothly instead of snapping forward on each sample.
  mbx.PolylineAnnotation? _telemetryTipAnnotation;
  bool _telemetryTipUpdateInFlight = false;
  bool _telemetryTipUpdatePending = false;

  @override
  void initState() {
    super.initState();
    widget.flyToNotifier?.addListener(_onFlyToChanged);
    _userMarkerAnim = AnimationController(
      vsync: this,
      duration: _kUserMarkerGlideDuration,
    )..addListener(_onUserMarkerTick);
    _animatedUserLocation = widget.userLocation;
    _userBearing = widget.userBearing;
    // Only recording maps restore the persisted style; everything else stays
    // on the classic Outdoors default.
    if (widget.persistStyle) _loadMapStyle();
  }

  /// Lazily renders the navigation arrow bitmap once. Drawn at the device
  /// pixel ratio (and scaled back down via `iconSize`) so it stays crisp on
  /// high-DPI screens. Same blue/white styling as the circle, slightly
  /// larger so the direction reads clearly.
  Future<void> _ensureArrowImage() async {
    if (_arrowImageBytes != null || !mounted) return;
    _arrowDpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 3.0;
    _arrowImageBytes = await _buildArrowImage(_arrowDpr);
  }

  Future<Uint8List> _buildArrowImage(double dpr) async {
    const logical = 90.0; // ~70% larger than the 20pt circle diameter.
    final px = logical * dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = px / 2;
    final halfW = px * 0.32;
    final tipY = px * 0.10;
    final baseY = px * 0.86;
    final notchY = px * 0.62;
    // A navigation chevron pointing up (north). `iconRotate` then aims it.
    final path = Path()
      ..moveTo(center, tipY)
      ..lineTo(center + halfW, baseY)
      ..lineTo(center, notchY)
      ..lineTo(center - halfW, baseY)
      ..close();
    final fill = Paint()
      ..color = const Color(0xFF2196F3)
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * dpr
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    final image = await recorder.endRecording().toImage(px.round(), px.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _ensureFinishFlagImage() async {
    if (_finishFlagImageBytes != null || !mounted) return;
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 3.0;
    _finishFlagImageBytes = await _buildFinishFlagImage(dpr);
  }

  Future<Uint8List> _buildFinishFlagImage(double dpr) async {
    const logical = 32.0;
    final px = logical * dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = px;
    final r = size / 2;

    // White circle background with dark border.
    canvas.drawCircle(
      Offset(r, r),
      r,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawCircle(
      Offset(r, r),
      r,
      Paint()
        ..color = const Color(0xFF212121)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * dpr,
    );

    // 4x4 checkered pattern inside the circle (clipped).
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(r, r), radius: r - 1.5 * dpr)));
    final cellSize = (size - 4 * dpr) / 4;
    final origin = 2.0 * dpr;
    final black = Paint()..color = const Color(0xFF212121);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        if ((row + col) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(
              origin + col * cellSize,
              origin + row * cellSize,
              cellSize,
              cellSize,
            ),
            black,
          );
        }
      }
    }
    canvas.restore();

    final img = await recorder.endRecording().toImage(px.round(), px.round());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _loadMapStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kMapStyleKey);
    if (stored == null || !mounted) return;
    final parsed = MapStyle.values.where((s) => s.name == stored);
    if (parsed.isEmpty) return;
    setState(() => _mapStyle = parsed.first);
    // Apply to the native map if it already exists; otherwise [_onMapCreated]
    // reconciles once the map is ready. On later sessions the prefs read is
    // warm and usually resolves *before* the map is created, so without that
    // fallback the restored style would update the switcher but never the map.
    await _applyMapStyle();
  }

  Future<void> _switchStyle(MapStyle style) async {
    if (style == _mapStyle) return;
    setState(() => _mapStyle = style);
    // Only recording maps remember the choice; elsewhere the switch is a
    // session-local preview that doesn't touch the saved preference.
    if (widget.persistStyle) {
      unawaited(SharedPreferences.getInstance()
          .then((p) => p.setString(_kMapStyleKey, style.name)));
    }
    await _applyMapStyle();
  }

  /// Reconciles the native map's loaded style with [_mapStyle] — the single
  /// source of truth, also shown selected in the switcher. No-op until the map
  /// exists, and whenever the desired style is already loaded. Overlapping
  /// calls coalesce like [_renderAnnotations] so a style change arriving
  /// mid-swap is still applied.
  Future<void> _applyMapStyle() async {
    final map = _map;
    if (map == null || !mounted) return;
    if (_activeStyleUri == _mapStyle.uri) return;
    if (_applyingStyle) {
      _applyStylePending = true;
      return;
    }
    _applyingStyle = true;
    try {
      final desired = _mapStyle.uri;
      // Tear down the annotation managers *before* the style reload. Once
      // loadStyleURI runs, the native counterparts of these managers are gone,
      // and removing them afterwards would crash with "No manager found with
      // id: N" (an uncatchable native exception thrown inside getManager).
      await _removeManagers(map);
      await map.loadStyleURI(desired);
      _activeStyleUri = desired;
      if (!mounted) return;
      await _createManagers(map);
      await _renderAnnotations();
    } finally {
      _applyingStyle = false;
      if (_applyStylePending) {
        _applyStylePending = false;
        unawaited(_applyMapStyle());
      }
    }
  }

  /// Removes the current annotation managers while their native counterparts
  /// are still valid (i.e. before any style reload). References are nulled
  /// *synchronously* up front so concurrent animation ticks / renders bail out
  /// via their null-manager guards instead of touching managers mid-removal.
  Future<void> _removeManagers(mbx.MapboxMap map) async {
    final oldLine = _lineManager;
    final oldCircle = _circleManager;
    final oldArrow = _arrowManager;
    final oldFinish = _finishMarkerManager;
    _lineManager = null;
    _circleManager = null;
    _arrowManager = null;
    _finishMarkerManager = null;
    // The old user-marker handles belonged to the removed managers — drop
    // them so the next render recreates them on the new managers.
    _userCircleAnnotation = null;
    _userArrowAnnotation = null;
    _telemetryTipAnnotation = null;
    if (oldLine != null) {
      try {
        await map.annotations.removeAnnotationManager(oldLine);
      } on PlatformException catch (_) {}
    }
    if (oldCircle != null) {
      try {
        await map.annotations.removeAnnotationManager(oldCircle);
      } on PlatformException catch (_) {}
    }
    if (oldArrow != null) {
      try {
        await map.annotations.removeAnnotationManager(oldArrow);
      } on PlatformException catch (_) {}
    }
    if (oldFinish != null) {
      try {
        await map.annotations.removeAnnotationManager(oldFinish);
      } on PlatformException catch (_) {}
    }
  }

  /// Creates fresh annotation managers on the currently-loaded style. Call
  /// only after a style has finished loading.
  Future<void> _createManagers(mbx.MapboxMap map) async {
    try {
      _lineManager = await map.annotations.createPolylineAnnotationManager();
      _circleManager = await map.annotations.createCircleAnnotationManager();
    } on PlatformException {
      // Channel torn down — leave managers null; a later render retries.
      return;
    }
    await _createArrowManager(map);
    await _createFinishMarkerManager(map);
  }

  @override
  void dispose() {
    widget.flyToNotifier?.removeListener(_onFlyToChanged);
    _userMarkerAnim.dispose();
    final map = _map;
    if (map != null) {
      map.removeInteraction('splitway-tap');
      map.removeInteraction('splitway-long-tap');
    }
    super.dispose();
  }

  /// Called on every animation frame while the user-marker is gliding between
  /// two GPS samples. Interpolates the current position and pushes it to the
  /// existing circle annotation via [_ensureUserMarker] (no full re-render).
  void _onUserMarkerTick() {
    final start = _markerStart;
    final end = _markerEnd;
    if (start == null || end == null) return;
    final t = _userMarkerAnim.value;
    _animatedUserLocation = GeoPoint(
      latitude: start.latitude + (end.latitude - start.latitude) * t,
      longitude: start.longitude + (end.longitude - start.longitude) * t,
    );
    // Fire-and-forget: each helper coalesces its own overlapping calls.
    unawaited(_ensureUserMarker());
    unawaited(_ensureTelemetryTip());
  }

  /// Starts (or restarts) the glide animation from the currently-visible
  /// position to [target]. The first time a user location appears, we snap
  /// instantly — there is nothing to animate from.
  void _animateUserMarkerTo(GeoPoint? target) {
    if (target == null) {
      // User location was cleared.
      _userMarkerAnim.stop();
      _markerStart = null;
      _markerEnd = null;
      _animatedUserLocation = null;
      unawaited(_ensureUserMarker());
      return;
    }
    final from = _animatedUserLocation;
    if (from == null) {
      // First fix — show immediately, no glide.
      _animatedUserLocation = target;
      _markerStart = target;
      _markerEnd = target;
      unawaited(_ensureUserMarker());
      return;
    }
    _markerStart = from;
    _markerEnd = target;
    _userMarkerAnim
      ..stop()
      ..forward(from: 0);
  }

  /// Creates the user-location circle on first use, updates its geometry
  /// in-place on subsequent frames, or removes it when there is no fix.
  /// Coalesces overlapping calls so the Pigeon channel isn't flooded if the
  /// animation ticks faster than the platform side can apply updates.
  Future<void> _ensureUserMarker() async {
    if (_isRendering) return;
    if (_userMarkerUpdateInFlight) {
      _userMarkerUpdatePending = true;
      return;
    }
    _userMarkerUpdateInFlight = true;
    try {
      await _ensureUserMarkerCore();
    } finally {
      _userMarkerUpdateInFlight = false;
      if (_userMarkerUpdatePending) {
        _userMarkerUpdatePending = false;
        unawaited(_ensureUserMarker());
      }
    }
  }

  Future<void> _ensureUserMarkerCore() async {
    final circleMgr = _circleManager;
    if (circleMgr == null || !mounted) return;
    final pos = _animatedUserLocation;

    if (pos == null) {
      await _removeUserCircle();
      await _removeUserArrow();
      return;
    }

    final geometry = mbx.Point(
      coordinates: mbx.Position(pos.longitude, pos.latitude),
    );

    // Show the directional arrow once the heading is known (and the bitmap
    // is ready); otherwise fall back to the plain circle.
    final bearing = _userBearing;
    final useArrow = bearing != null &&
        _arrowManager != null &&
        _arrowImageBytes != null;

    if (useArrow) {
      await _removeUserCircle();
      await _ensureUserArrow(geometry, bearing);
    } else {
      await _removeUserArrow();
      await _ensureUserCircle(geometry, circleMgr);
    }
  }

  Future<void> _ensureUserCircle(
      mbx.Point geometry, mbx.CircleAnnotationManager circleMgr) async {
    final existing = _userCircleAnnotation;
    if (existing == null) {
      try {
        _userCircleAnnotation = await circleMgr.create(
          mbx.CircleAnnotationOptions(
            geometry: geometry,
            circleColor: 0xFF2196F3,
            circleRadius: 10,
            circleStrokeColor: 0xFFFFFFFF,
            circleStrokeWidth: 3,
          ),
        );
      } on PlatformException {
        // Channel torn down — try again on the next render.
      }
    } else {
      existing.geometry = geometry;
      try {
        await circleMgr.update(existing);
      } on PlatformException {
        // Handle invalidated (style swap, dispose) — clear so the next tick
        // recreates it.
        _userCircleAnnotation = null;
      }
    }
  }

  Future<void> _ensureUserArrow(mbx.Point geometry, double bearing) async {
    final arrowMgr = _arrowManager;
    final bytes = _arrowImageBytes;
    if (arrowMgr == null || bytes == null) return;
    final existing = _userArrowAnnotation;
    if (existing == null) {
      try {
        _userArrowAnnotation = await arrowMgr.create(
          mbx.PointAnnotationOptions(
            geometry: geometry,
            image: bytes,
            iconRotate: bearing,
            // Bitmap drawn at the device pixel ratio — scale it back down.
            iconSize: 1 / _arrowDpr,
          ),
        );
      } on PlatformException {
        // Channel torn down — retry on the next tick.
      }
    } else {
      existing.geometry = geometry;
      existing.iconRotate = bearing;
      try {
        await arrowMgr.update(existing);
      } on PlatformException {
        _userArrowAnnotation = null;
      }
    }
  }

  Future<void> _removeUserCircle() async {
    final mgr = _circleManager;
    final existing = _userCircleAnnotation;
    if (mgr == null || existing == null) return;
    try {
      await mgr.delete(existing);
    } on PlatformException {
      // Channel torn down — drop the handle silently.
    }
    _userCircleAnnotation = null;
  }

  Future<void> _removeUserArrow() async {
    final mgr = _arrowManager;
    final existing = _userArrowAnnotation;
    if (mgr == null || existing == null) return;
    try {
      await mgr.delete(existing);
    } on PlatformException {
      // Channel torn down — drop the handle silently.
    }
    _userArrowAnnotation = null;
  }

  /// True while the recorded line's final segment should animate toward the
  /// gliding user marker: a live position is being tracked AND recording is
  /// active. False off-recording (e.g. the review map) or once the route has
  /// finished, so the whole trail is drawn statically and freezes in place.
  bool get _growsTip => _animatedUserLocation != null && widget.recording;

  /// Per-frame in-place update of the growing tip segment so the recorded
  /// line follows the gliding user marker. Only 2 points are sent, so this is
  /// cheap even on long tracks. Coalesces overlapping calls and stands down
  /// while a full re-render is in flight (which rebuilds the static line).
  Future<void> _ensureTelemetryTip() async {
    if (_isRendering) return;
    if (_telemetryTipUpdateInFlight) {
      _telemetryTipUpdatePending = true;
      return;
    }
    _telemetryTipUpdateInFlight = true;
    try {
      await _ensureTelemetryTipCore();
    } finally {
      _telemetryTipUpdateInFlight = false;
      if (_telemetryTipUpdatePending) {
        _telemetryTipUpdatePending = false;
        unawaited(_ensureTelemetryTip());
      }
    }
  }

  Future<void> _ensureTelemetryTipCore() async {
    final lineMgr = _lineManager;
    if (lineMgr == null || !mounted) return;
    final tel = widget.telemetry;
    final animated = _animatedUserLocation;
    final useHeatmap =
        widget.showSpeedHeatmap && _hasUsableSpeedTelemetry(tel);
    final showTip =
        !useHeatmap && tel.length >= 2 && animated != null && widget.recording;
    if (!showTip) {
      await _removeTelemetryTip();
      return;
    }
    // Anchor the tip at the last *confirmed* point and grow toward the
    // gliding position; the static line ends at the same anchor, so the two
    // meet seamlessly.
    final anchor = tel[tel.length - 2].location;
    final tipGeom = _toLineString([anchor, animated]);
    final existing = _telemetryTipAnnotation;
    if (existing == null) {
      try {
        _telemetryTipAnnotation = await lineMgr.create(
          mbx.PolylineAnnotationOptions(
            geometry: tipGeom,
            lineColor: 0xFFE65100,
            lineWidth: 5,
            lineOpacity: 0.85,
          ),
        );
      } on PlatformException {
        // Channel torn down — retry on the next tick.
      }
    } else {
      existing.geometry = tipGeom;
      try {
        await lineMgr.update(existing);
      } on PlatformException {
        // Handle invalidated by a full re-render / style swap — drop it.
        _telemetryTipAnnotation = null;
      }
    }
  }

  Future<void> _removeTelemetryTip() async {
    final lineMgr = _lineManager;
    final existing = _telemetryTipAnnotation;
    if (lineMgr == null || existing == null) return;
    try {
      await lineMgr.delete(existing);
    } on PlatformException {
      // Channel torn down — drop the handle silently.
    }
    _telemetryTipAnnotation = null;
  }

  void _onFlyToChanged() {
    final notifier = widget.flyToNotifier;
    final target = notifier?.target;
    if (target == null || _map == null || !mounted) return;
    final bearing = notifier?.bearing;
    final pitch = notifier?.pitch;
    final durationMs = notifier?.animationDuration.inMilliseconds ?? 800;
    // Navigation follow-mode: shift the focal point downward so the user
    // marker sits ~25% from the bottom of the map, giving ~75% of the view to
    // what's ahead — matching Google Maps' turn-by-turn perspective. The
    // pitch value is the discriminator: only recording/free-ride flyTos pass
    // it; preview/editor flyTos leave padding null and stay centred.
    mbx.MbxEdgeInsets? padding;
    if (pitch != null) {
      final size = context.size;
      if (size != null) {
        padding = mbx.MbxEdgeInsets(
          top: size.height * 0.5,
          left: 0,
          bottom: 0,
          right: 0,
        );
      }
    }
    _map!.flyTo(
      mbx.CameraOptions(
        center: mbx.Point(
          coordinates: mbx.Position(target.longitude, target.latitude),
        ),
        zoom: 17,
        bearing: bearing,
        pitch: pitch,
        padding: padding,
      ),
      mbx.MapAnimationOptions(duration: durationMs),
    ).catchError((_) {
      // Map channel torn down — ignore silently.
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.useMapbox) {
      return _buildPainterFallback();
    }
    final mapWidget = mbx.MapWidget(
      key: const ValueKey('splitway-mapbox'),
      styleUri: widget.styleUri ?? _mapStyle.uri,
      onMapCreated: _onMapCreated,
    );

    final showStyleButton = widget.interactive && widget.useMapbox;

    // Detect user-initiated map gestures (pan/zoom/tap) so the caller can
    // disable GPS-follow mode. The Listener uses translucent hit behaviour so
    // events are NOT consumed — Mapbox still handles all its own gestures.
    final Widget baseMap = widget.onUserInteraction != null
        ? Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => widget.onUserInteraction!(),
            child: mapWidget,
          )
        : mapWidget;

    return Stack(
      children: [
        baseMap,
        if (widget.freehandMode)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
            ),
          ),
        if (showStyleButton)
          Positioned(
            // Sits just below the Mapbox compass (anchored top-right,
            // ~40dp tall with an 8dp top margin).
            top: 56,
            right: 8,
            child: _buildStyleButton(context),
          ),
      ],
    );
  }

  Widget _buildStyleButton(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return PopupMenuButton<MapStyle>(
      onSelected: _switchStyle,
      tooltip: l.mapStyleLayersTooltip,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        for (final style in MapStyle.values)
          PopupMenuItem<MapStyle>(
            value: style,
            child: Row(
              children: [
                Icon(style.icon,
                    size: 20,
                    color: style == _mapStyle
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Text(
                  style.label(l),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: style == _mapStyle
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: style == _mapStyle
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 16),
                if (style == _mapStyle)
                  Icon(Icons.check,
                      size: 18, color: theme.colorScheme.primary),
              ],
            ),
          ),
      ],
      child: Material(
        elevation: 4,
        shape: const CircleBorder(),
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.layers,
              size: 22, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant SplitwayMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flyToNotifier != widget.flyToNotifier) {
      oldWidget.flyToNotifier?.removeListener(_onFlyToChanged);
      widget.flyToNotifier?.addListener(_onFlyToChanged);
    }
    if (!widget.useMapbox) return;

    if (oldWidget.freehandMode != widget.freehandMode) {
      _updateGesturesForFreehand();
    }

    final routeChanged = oldWidget.route != widget.route;
    final userLocationChanged = oldWidget.userLocation != widget.userLocation;
    final annotationsChanged = routeChanged ||
        oldWidget.telemetry.length != widget.telemetry.length ||
        oldWidget.draftPath.length != widget.draftPath.length ||
        oldWidget.draftWaypoints.length != widget.draftWaypoints.length ||
        oldWidget.draftSectorPoints.length != widget.draftSectorPoints.length ||
        oldWidget.highlightSectorId != widget.highlightSectorId ||
        oldWidget.showSectors != widget.showSectors ||
        oldWidget.draftSegments.length != widget.draftSegments.length ||
        oldWidget.freehandMode != widget.freehandMode ||
        oldWidget.showSpeedHeatmap != widget.showSpeedHeatmap ||
        oldWidget.speedHeatmapUnit != widget.speedHeatmapUnit ||
        oldWidget.finishMarker != widget.finishMarker ||
        oldWidget.recording != widget.recording;

    if (annotationsChanged) _renderAnnotations();

    // User-location updates are handled by the dedicated marker animation so
    // the dot glides smoothly instead of teleporting on every GPS sample.
    final userBearingChanged = oldWidget.userBearing != widget.userBearing;
    _userBearing = widget.userBearing;
    if (userLocationChanged) {
      _animateUserMarkerTo(widget.userLocation);
    } else if (userBearingChanged) {
      // Heading changed without a new fix (e.g. compass rotation while
      // stationary) — refresh the marker so the arrow re-aims / the
      // circle↔arrow swap happens.
      unawaited(_ensureUserMarker());
    }

    // Fly to fit whenever the user selects a different route.
    if (routeChanged) _flyToFitRoute();
  }

  Widget _buildPainterFallback() {
    final route = widget.route;
    if (route == null) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(child: Text(AppLocalizations.of(context).mapNoRoute)),
      );
    }
    return CustomPaint(
      painter: RouteMapPainter(
        route: route,
        telemetry: widget.telemetry,
        highlightSectorId: widget.highlightSectorId,
        showSectors: widget.showSectors,
        finishMarker: widget.finishMarker,
      ),
      child: const SizedBox.expand(),
    );
  }

  GeoPoint _focusPoint() {
    if (widget.route?.path.isNotEmpty ?? false) {
      return widget.route!.path.first;
    }
    if (widget.draftPath.isNotEmpty) return widget.draftPath.first;
    if (widget.initialCenter != null) return widget.initialCenter!;
    return const GeoPoint(latitude: 40.4168, longitude: -3.7038);
  }

  Future<void> _onMapCreated(mbx.MapboxMap map) async {
    _map = map;
    // The native view is created with the styleUri from its first build, when
    // [_mapStyle] is still the default (the persisted style only lands after
    // the first frame). Record it so [_applyMapStyle] below can reconcile if a
    // non-default style was restored before the map existed.
    _activeStyleUri = widget.styleUri ?? MapStyle.outdoors.uri;
    // Position camera immediately (no animation) to avoid a blank-map flash.
    final center = _focusPoint();
    await map.setCamera(mbx.CameraOptions(
      center: mbx.Point(
        coordinates: mbx.Position(center.longitude, center.latitude),
      ),
      zoom: 11,
    ));
    // Register tap / long-tap interactions via the non-deprecated API.
    if (widget.onTap != null) {
      map.addInteraction(
        mbx.TapInteraction.onMap(_handleTap),
        interactionID: 'splitway-tap',
      );
    }
    if (widget.onLongPress != null) {
      map.addInteraction(
        mbx.LongTapInteraction.onMap(_handleLongTap),
        interactionID: 'splitway-long-tap',
      );
    }
    if (!widget.interactive) {
      await map.gestures.updateSettings(mbx.GesturesSettings(
        scrollEnabled: false,
        rotateEnabled: false,
        pinchToZoomEnabled: false,
        doubleTapToZoomInEnabled: false,
        doubleTouchToZoomOutEnabled: false,
        quickZoomEnabled: false,
        pitchEnabled: false,
        pinchPanEnabled: false,
      ));
    }
    // Create *all* annotation managers (incl. the finish-flag manager) up
    // front. Inlining a subset here previously left _finishMarkerManager null
    // until the first style switch, so the checkered flag never showed on the
    // initial load.
    await _createManagers(map);
    await _ensureArrowImage();
    await _ensureFinishFlagImage();
    await _updateGesturesForFreehand();
    await _renderAnnotations();
    await _flyToFitRoute();
    // Reconcile the rendered style with the (possibly restored) [_mapStyle]:
    // if the prefs read won the race and set a non-default style before the
    // map existed, this is where it finally gets loaded.
    await _applyMapStyle();
  }

  /// Creates the dedicated point manager for the directional user arrow and
  /// pins its rotation to the map frame so `iconRotate` is interpreted as an
  /// absolute compass bearing (the arrow points the right way regardless of
  /// how the camera is rotated).
  Future<void> _createArrowManager(mbx.MapboxMap map) async {
    try {
      final mgr = await map.annotations.createPointAnnotationManager();
      await mgr.setIconRotationAlignment(mbx.IconRotationAlignment.MAP);
      await mgr.setIconAllowOverlap(true);
      await mgr.setIconIgnorePlacement(true);
      _arrowManager = mgr;
    } on PlatformException {
      // Map channel torn down — leave the arrow manager null; the circle
      // fallback still renders the user position.
    }
  }

  Future<void> _createFinishMarkerManager(mbx.MapboxMap map) async {
    try {
      final mgr = await map.annotations.createPointAnnotationManager();
      await mgr.setIconAllowOverlap(true);
      await mgr.setIconIgnorePlacement(true);
      _finishMarkerManager = mgr;
    } on PlatformException {
      // Channel torn down — the checkered flag won't render but nothing breaks.
    }
  }

  /// Draws the checkered finish flag at [center]. No-op until the marker
  /// manager and flag image are ready.
  Future<void> _createFinishFlag(GeoPoint center) async {
    final finishMgr = _finishMarkerManager;
    final finishImg = _finishFlagImageBytes;
    if (finishMgr == null || finishImg == null || !mounted) return;
    try {
      await finishMgr.create(mbx.PointAnnotationOptions(
        geometry: mbx.Point(
          coordinates: mbx.Position(center.longitude, center.latitude),
        ),
        image: finishImg,
        iconSize: 1 / (_arrowDpr),
        iconAnchor: mbx.IconAnchor.CENTER,
      ));
    } on PlatformException {
      // Channel torn down — skip silently.
    }
  }

  Future<void> _updateGesturesForFreehand() async {
    final map = _map;
    if (map == null) return;
    if (widget.freehandMode) {
      await map.gestures.updateSettings(mbx.GesturesSettings(
        scrollEnabled: false,
        pinchToZoomEnabled: true,
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
        rotateEnabled: false,
        quickZoomEnabled: false,
        pitchEnabled: false,
        pinchPanEnabled: false,
      ));
    } else if (widget.interactive) {
      await map.gestures.updateSettings(mbx.GesturesSettings(
        scrollEnabled: true,
        pinchToZoomEnabled: true,
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
        rotateEnabled: true,
        quickZoomEnabled: true,
        pitchEnabled: true,
        pinchPanEnabled: true,
      ));
    }
  }

  Future<void> _flyToFitRoute() async {
    final map = _map;
    if (map == null || !mounted) return;
    final geometry = _allGeometry();
    if (geometry.isEmpty) return;

    double minLat = geometry.first.latitude;
    double maxLat = minLat;
    double minLng = geometry.first.longitude;
    double maxLng = minLng;
    for (final p in geometry) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Use the SDK's own algorithm to compute the camera that fits the
    // bounding box. Padding of 80/60 dp gives a comfortable margin.
    final bounds = mbx.CoordinateBounds(
      southwest: mbx.Point(
          coordinates: mbx.Position(minLng, minLat)),
      northeast: mbx.Point(
          coordinates: mbx.Position(maxLng, maxLat)),
      infiniteBounds: false,
    );

    final padding = widget.interactive
        ? mbx.MbxEdgeInsets(top: 80, left: 60, bottom: 80, right: 60)
        : mbx.MbxEdgeInsets(top: 40, left: 30, bottom: 40, right: 30);

    try {
      final camera = await map.cameraForCoordinateBounds(
        bounds,
        padding,
        null,   // bearing
        null,   // pitch
        18.0,   // maxZoom — never closer than z18
        null,   // offset
      );
      if (!mounted) return;
      await map.flyTo(camera, mbx.MapAnimationOptions(duration: 800));
    } on PlatformException {
      // Map channel torn down — nothing to animate.
      return;
    } catch (_) {
      // cameraForCoordinateBounds failed (e.g. degenerate bounds).
      // Fallback: fly to the centre at a safe zoom level.
      if (!mounted) return;
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      try {
        await map.flyTo(
          mbx.CameraOptions(
            center: mbx.Point(
                coordinates: mbx.Position(centerLng, centerLat)),
            zoom: 14,
          ),
          mbx.MapAnimationOptions(duration: 800),
        );
      } on PlatformException {
        // Channel gone — ignore silently.
      }
    }
  }

  List<GeoPoint> _allGeometry() {
    final all = <GeoPoint>[];
    final r = widget.route;
    if (r != null) {
      all.addAll(r.path);
      all
        ..add(r.startFinishGate.left)
        ..add(r.startFinishGate.right);
      for (final s in r.sectors) {
        all
          ..add(s.gate.left)
          ..add(s.gate.right);
      }
    }
    all.addAll(widget.draftPath);
    all.addAll(widget.draftSectorPoints);
    for (final t in widget.telemetry) {
      all.add(t.location);
    }
    return all;
  }

  Future<void> _renderAnnotations() async {
    // Coalesce rapid calls: if a render is already in progress, mark pending
    // and return. The in-progress render will re-run when it finishes.
    if (_isRendering) {
      _renderPending = true;
      return;
    }
    _isRendering = true;
    try {
      await _renderAnnotationsCore();
    } finally {
      _isRendering = false;
      // If a new render was requested while we were busy, run it now.
      if (_renderPending) {
        _renderPending = false;
        _renderAnnotations();
      }
    }
  }

  Future<void> _renderAnnotationsCore() async {
    final lineMgr = _lineManager;
    final circleMgr = _circleManager;
    if (lineMgr == null || circleMgr == null) return;

    try {
      await lineMgr.deleteAll();
      await circleMgr.deleteAll();
      await _finishMarkerManager?.deleteAll();
    } on PlatformException {
      // Map channel torn down (e.g. widget disposed mid-render). Bail out.
      return;
    }
    _userCircleAnnotation = null;
    _telemetryTipAnnotation = null;
    if (!mounted) return;

    // Speed heatmap takes over the route+telemetry rendering when active.
    final useHeatmap =
        widget.showSpeedHeatmap && _hasUsableSpeedTelemetry(widget.telemetry);
    if (useHeatmap) {
      await _applyHeatmapLayer(widget.telemetry, widget.speedHeatmapUnit);
    } else {
      await _removeHeatmapLayer();
    }

    final r = widget.route;
    if (!useHeatmap && r != null && r.path.isNotEmpty) {
      if (widget.showSectors && r.sectors.isNotEmpty) {
        // Draw each sector segment in a different color.
        final segments = computeSectorSegments(r.path, r.sectors);
        for (var i = 0; i < segments.length; i++) {
          if (segments[i].length < 2) continue;
          if (!mounted) return;
          try {
            await lineMgr.create(mbx.PolylineAnnotationOptions(
              geometry: _toLineString(segments[i]),
              lineColor: kSectorColors[i % kSectorColors.length].toARGB32(),
              lineWidth: 7,
            ));
          } on PlatformException {
            return;
          }
        }
      } else {
        if (!mounted) return;
        try {
          await lineMgr.create(mbx.PolylineAnnotationOptions(
            geometry: _toLineString(r.path),
            lineColor: 0xFF1565C0,
            lineWidth: 7,
          ));
        } on PlatformException {
          return;
        }
      }
      if (widget.showSectors && r.sectors.isNotEmpty) {
        // Show sector boundary points as colored circles on the route.
        for (var i = 0; i < r.sectors.length; i++) {
          if (!mounted) return;
          final center = r.sectors[i].gate.center;
          try {
            await circleMgr.create(mbx.CircleAnnotationOptions(
              geometry: mbx.Point(
                  coordinates: mbx.Position(center.longitude, center.latitude)),
              circleColor: kSectorColors[(i + 1) % kSectorColors.length].toARGB32(),
              circleRadius: 6,
              circleStrokeColor: 0xFFFFFFFF,
              circleStrokeWidth: 2,
            ));
          } on PlatformException {
            return;
          }
        }
      }
    }

    // Checkered finish flag: at the route's last path node, or — for a
    // finished free ride without a route — at the explicit [finishMarker].
    // Hidden while the heatmap is active, matching the route line.
    if (!useHeatmap && mounted) {
      final finishCenter = (r != null && r.path.isNotEmpty)
          ? r.path.last
          : (r == null ? widget.finishMarker : null);
      if (finishCenter != null) {
        await _createFinishFlag(finishCenter);
      }
    }

    if (!mounted) return;
    if (!useHeatmap && widget.telemetry.length >= 2) {
      final tel = widget.telemetry;
      // While recording, the final segment is animated by the tip annotation,
      // so the static line stops at the last confirmed point. Off-recording
      // the whole track is drawn statically.
      final staticPoints = _growsTip
          ? tel.sublist(0, tel.length - 1)
          : tel;
      final staticPath =
          staticPoints.map((t) => t.location).toList(growable: false);
      if (staticPath.length >= 2) {
        try {
          await lineMgr.create(mbx.PolylineAnnotationOptions(
            geometry: _toLineString(staticPath),
            lineColor: 0xFFE65100,
            lineWidth: 5,
            lineOpacity: 0.85,
          ));
        } on PlatformException {
          return;
        }
      }
    }

    if (!mounted) return;
    // Draft segments: snapped = purple, freehand = orange.
    if (widget.draftSegments.isNotEmpty) {
      for (final seg in widget.draftSegments) {
        final rendered = seg.renderedPath;
        if (rendered.length < 2) continue;
        if (!mounted) return;
        final color = seg is FreehandSegment ? 0xFFEF6C00 : 0xFF6A1B9A;
        try {
          await lineMgr.create(mbx.PolylineAnnotationOptions(
            geometry: _toLineString(rendered),
            lineColor: color,
            lineWidth: 3,
          ));
        } on PlatformException {
          return;
        }
      }
    } else if (widget.draftPath.length >= 2) {
      // Backward compat: fall back to flat draftPath.
      try {
        await lineMgr.create(mbx.PolylineAnnotationOptions(
          geometry: _toLineString(widget.draftPath),
          lineColor: 0xFF6A1B9A,
          lineWidth: 3,
        ));
      } on PlatformException {
        return;
      }
    }
    // Draw circles only for the user-tapped waypoints, not for every point
    // in the snapped path (which can have thousands of points and would
    // saturate the Pigeon channel).
    for (final p in widget.draftWaypoints) {
      if (!mounted) return;
      try {
        await circleMgr.create(mbx.CircleAnnotationOptions(
          geometry: mbx.Point(
              coordinates: mbx.Position(p.longitude, p.latitude)),
          circleColor: 0xFF6A1B9A,
          circleRadius: 6,
        ));
      } on PlatformException {
        return;
      }
    }
    for (var i = 0; i < widget.draftSectorPoints.length; i++) {
      if (!mounted) return;
      final p = widget.draftSectorPoints[i];
      try {
        await circleMgr.create(mbx.CircleAnnotationOptions(
          geometry: mbx.Point(coordinates: mbx.Position(p.longitude, p.latitude)),
          circleColor: kSectorColors[i % kSectorColors.length].toARGB32(),
          circleRadius: 6,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 2,
        ));
      } on PlatformException {
        return;
      }
    }

    if (!mounted) return;
    _userMarkerUpdatePending = false;
    await _ensureUserMarkerCore();
    _telemetryTipUpdatePending = false;
    await _ensureTelemetryTipCore();
  }

  mbx.LineString _toLineString(List<GeoPoint> points) {
    return mbx.LineString(
      coordinates:
          points.map((p) => mbx.Position(p.longitude, p.latitude)).toList(),
    );
  }

  bool _hasUsableSpeedTelemetry(List<TelemetryPoint> tel) {
    if (tel.length < 2) return false;
    var withSpeed = 0;
    for (final p in tel) {
      if (p.speedMps != null) {
        withSpeed += 1;
        if (withSpeed >= 2) return true;
      }
    }
    return false;
  }

  /// Builds (or rebuilds) the heatmap GeoJSON source and LineLayer with a
  /// `line-gradient` expression so the line is colored continuously by speed.
  Future<void> _applyHeatmapLayer(
      List<TelemetryPoint> tel, UnitSystem unit) async {
    final map = _map;
    if (map == null || !mounted) return;

    // Compute the rounded "nice" max so the gradient consumes the full
    // palette range (legend uses the same niceMaxMps).
    var rawMax = 0.0;
    for (final p in tel) {
      final s = p.speedMps;
      if (s != null && s > rawMax) rawMax = s;
    }
    final maxMps = niceMaxMps(rawMax, unit);
    final stops = buildSpeedHeatmapStops(telemetry: tel, maxMps: maxMps);
    if (stops.isEmpty) {
      await _removeHeatmapLayer();
      return;
    }

    // Build the GeoJSON LineString from ALL telemetry points (geometry stays
    // dense and continuous; only the gradient stop list is decimated).
    final coords = <List<double>>[];
    for (final p in tel) {
      coords.add([p.location.longitude, p.location.latitude]);
    }
    final geoJson = jsonEncode({
      'type': 'Feature',
      'geometry': {'type': 'LineString', 'coordinates': coords},
      'properties': <String, dynamic>{},
    });

    // Mapbox interpolate expression along line-progress.
    final expr = <Object>[
      'interpolate',
      <Object>['linear'],
      <Object>['line-progress'],
    ];
    for (final stop in stops) {
      final c = stop.color;
      expr.add(stop.progress);
      expr.add(<Object>[
        'rgba',
        (c.r * 255.0).round().clamp(0, 255),
        (c.g * 255.0).round().clamp(0, 255),
        (c.b * 255.0).round().clamp(0, 255),
        c.a,
      ]);
    }

    try {
      if (await map.style.styleLayerExists(_kHeatmapLayerId)) {
        await map.style.removeStyleLayer(_kHeatmapLayerId);
      }
      if (await map.style.styleSourceExists(_kHeatmapSourceId)) {
        await map.style.removeStyleSource(_kHeatmapSourceId);
      }
      if (!mounted) return;
      await map.style.addSource(mbx.GeoJsonSource(
        id: _kHeatmapSourceId,
        data: geoJson,
        lineMetrics: true,
      ));
      if (!mounted) return;
      await map.style.addLayer(mbx.LineLayer(
        id: _kHeatmapLayerId,
        sourceId: _kHeatmapSourceId,
        lineCap: mbx.LineCap.ROUND,
        lineJoin: mbx.LineJoin.ROUND,
        lineWidth: 5,
        lineGradientExpression: expr,
      ));
    } on PlatformException {
      // Map channel torn down; ignore.
    }
  }

  Future<void> _removeHeatmapLayer() async {
    final map = _map;
    if (map == null) return;
    try {
      if (await map.style.styleLayerExists(_kHeatmapLayerId)) {
        await map.style.removeStyleLayer(_kHeatmapLayerId);
      }
      if (await map.style.styleSourceExists(_kHeatmapSourceId)) {
        await map.style.removeStyleSource(_kHeatmapSourceId);
      }
    } on PlatformException {
      // Map channel torn down; ignore.
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length == 1) {
      _isFreehandStrokeActive = true;
      widget.onFreehandStart?.call();
      _convertAndSendFreehandPoint(event.localPosition);
    } else if (_isFreehandStrokeActive) {
      _isFreehandStrokeActive = false;
      widget.onFreehandEnd?.call();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isFreehandStrokeActive && _activePointers.length == 1) {
      _convertAndSendFreehandPoint(event.localPosition);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (_isFreehandStrokeActive && _activePointers.isEmpty) {
      _isFreehandStrokeActive = false;
      widget.onFreehandEnd?.call();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_isFreehandStrokeActive && _activePointers.isEmpty) {
      _isFreehandStrokeActive = false;
      widget.onFreehandEnd?.call();
    }
  }

  Future<void> _convertAndSendFreehandPoint(Offset screenPos) async {
    final map = _map;
    if (map == null) return;
    try {
      final point = await map.coordinateForPixel(mbx.ScreenCoordinate(
        x: screenPos.dx,
        y: screenPos.dy,
      ));
      final coords = point.coordinates;
      widget.onFreehandPoint?.call(GeoPoint(
        latitude: coords.lat.toDouble(),
        longitude: coords.lng.toDouble(),
        altitudeMeters: coords.alt?.toDouble(),
      ));
    } catch (_) {
      // Conversion failed — skip this point.
    }
  }

  void _handleTap(mbx.MapContentGestureContext ctx) {
    final coords = ctx.point.coordinates;
    widget.onTap?.call(GeoPoint(
      latitude: coords.lat.toDouble(),
      longitude: coords.lng.toDouble(),
      altitudeMeters: coords.alt?.toDouble(),
    ));
  }

  void _handleLongTap(mbx.MapContentGestureContext ctx) {
    final coords = ctx.point.coordinates;
    widget.onLongPress?.call(GeoPoint(
      latitude: coords.lat.toDouble(),
      longitude: coords.lng.toDouble(),
      altitudeMeters: coords.alt?.toDouble(),
    ));
  }
}
