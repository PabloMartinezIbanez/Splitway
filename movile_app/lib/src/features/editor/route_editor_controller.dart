import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:splitway_core/splitway_core.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/local_draft_repository.dart';
import '../../services/geocoding/reverse_geocoding_service.dart';
import '../../services/official_routes/official_routes_service.dart';
import '../../services/routing/elevation_service.dart';
import '../../services/routing/routing_service.dart';
import '../../services/sync/sync_service.dart';
import 'draft_segment.dart';

/// Which kind of input the next map tap should produce while drawing a
/// new route in the editor.
enum DrawInputMode {
  /// Each tap appends a point to the route path.
  appendPath,

  /// A single tap snaps to the nearest path vertex and auto-generates a
  /// perpendicular sector gate at that point.
  sectorPoint,

  /// Freehand drawing: pan gestures produce a continuous stroke.
  freehand,
}

/// One undoable user action, recorded so [RouteEditorController.undoLastAction]
/// can unwind path edits and sector additions as a single LIFO stack.
enum _UndoOp { pathPoint, sector }

class RouteEditorController extends ChangeNotifier {
  RouteEditorController(
    this._repo, {
    this.routingService,
    this.geocodingService,
    this.elevationService,
    String defaultRoutingProfile = 'driving',
    this.officialRoutesService,
  }) : _defaultRoutingProfile = defaultRoutingProfile {
    _routingProfile = _defaultRoutingProfile;
    _changesSub = _repo.changes.listen((_) => _onRepoChanged());
  }

  final LocalDraftRepository _repo;
  final String _defaultRoutingProfile;
  LocalDraftRepository get repository => _repo;
  StreamSubscription<void>? _changesSub;
  Timer? _reloadDebouncer;

  /// Optional: when present each new waypoint triggers a Mapbox Directions
  /// API call to snap the drawn path to actual roads in real time.
  final RoutingService? routingService;

  /// Optional: when present, reverse geocoding is called on save to populate
  /// the route's locationLabel field.
  final ReverseGeocodingService? geocodingService;

  /// Optional: when present, elevation data is fetched on save so the route
  /// gets a valid elevationRangeMeters value.
  final ElevationService? elevationService;

  /// Optional: when present, deletions are propagated to the remote backend
  /// so sync cannot re-download routes the user has deleted.
  SyncService? syncService;

  /// Optional: when present, deletions of official routes are routed through
  /// [OfficialRoutesService.dismiss] so the route is tombstoned locally
  /// (against its current `updated_at`) and a future modification on the
  /// Splitway side will re-introduce it.
  final OfficialRoutesService? officialRoutesService;

  List<SessionRun> _sessionsForSelected = const [];
  List<SessionRun> get sessionsForSelected => _sessionsForSelected;

  Map<String, int> _routeSessionCounts = const {};
  Map<String, int> get routeSessionCounts => _routeSessionCounts;

  Map<String, Duration?> _routeBestLaps = const {};
  Map<String, Duration?> get routeBestLaps => _routeBestLaps;

  bool _loading = true;
  bool get loading => _loading;

  /// True while a Mapbox snap request is in flight.
  bool _snapping = false;
  bool get snapping => _snapping;

  /// Outcome of the last snap attempt. `null` means "no attempt yet, or the
  /// last one succeeded"; anything else is a reason the UI can differentiate
  /// (rate limit vs generic connectivity failure). Resets on next success.
  RoutingFailureReason? _snapFailure;
  RoutingFailureReason? get snapFailure => _snapFailure;

  /// True when the last snap attempt failed for any reason. Kept for
  /// callers that don't care about the specific cause.
  bool get snapFailed => _snapFailure != null;

  /// True when the last snap attempt was rejected by rate limiting (either
  /// Mapbox's own or our proxy's), so the UI can show a distinct message.
  bool get snapRateLimited =>
      _snapFailure == RoutingFailureReason.rateLimited ||
      _snapFailure == RoutingFailureReason.cooldown;

  List<RouteTemplate> _routes = const [];
  List<RouteTemplate> get routes => _routes;

  RouteTemplate? _selected;
  RouteTemplate? get selected => _selected;

  // ---------- Draw mode state ----------

  bool _drawing = false;
  bool get drawing => _drawing;

  String _draftName = '';
  String? _draftDescription;
  RouteDifficulty _draftDifficulty = RouteDifficulty.medium;
  String get draftName => _draftName;
  String? get draftDescription => _draftDescription;
  RouteDifficulty get draftDifficulty => _draftDifficulty;

  final List<DraftSegment> _segments = [];
  List<DraftSegment> get segments => List.unmodifiable(_segments);

  List<GeoPoint> get draftPath {
    final path = <GeoPoint>[];
    for (final seg in _segments) {
      final rendered = seg.renderedPath;
      if (rendered.isEmpty) continue;
      if (path.isNotEmpty && rendered.isNotEmpty && path.last == rendered.first) {
        path.addAll(rendered.skip(1));
      } else {
        path.addAll(rendered);
      }
    }
    return path;
  }

  List<GeoPoint> get rawWaypoints {
    return [
      for (final seg in _segments)
        if (seg is SnappedSegment) ...seg.waypoints,
    ];
  }

  /// Number of user-tapped waypoints (shown in the status bar).
  int get draftWaypointCount => rawWaypoints.length;

  final List<GateDefinition> _draftSectorGates = [];
  List<GateDefinition> get draftSectorGates =>
      List.unmodifiable(_draftSectorGates);

  /// Path vertices snapped by the sectorPoint mode (parallel to _draftSectorGates).
  final List<GeoPoint> _draftSectorPoints = [];
  List<GeoPoint> get draftSectorPoints => List.unmodifiable(_draftSectorPoints);

  /// Maximum distance (m) between a tap and the nearest path vertex for a
  /// sector to be placed. Taps farther than this are ignored so a stray tap
  /// far from the route doesn't drop a misplaced sector.
  static const double _sectorSnapMaxDistanceMeters = 75.0;

  /// LIFO history of undoable actions. Path waypoints, freehand strokes and
  /// sector additions all push here so undo unwinds them in order.
  final List<_UndoOp> _undoStack = [];

  /// True when there is at least one action the user can undo.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Always null — retained for widget compatibility after removing 2-tap gate.
  GeoPoint? get pendingGateLeft => null;

  DrawInputMode _inputMode = DrawInputMode.appendPath;
  DrawInputMode get inputMode => _inputMode;

  String _routingProfile = 'driving';
  String get routingProfile => _routingProfile;
  set routingProfile(String value) {
    if (_routingProfile == value) return;
    _routingProfile = value;
    notifyListeners();
  }

  /// True if a draft can be persisted (≥2 path points and a name).
  bool get draftCanSave =>
      draftPath.length >= 2 && _draftName.trim().isNotEmpty;

  // Debounce live snapping so rapid taps only fire one API call.
  Timer? _snapDebouncer;
  // Monotonically-increasing generation counter — stale responses are ignored.
  int _snapGeneration = 0;

  void _onRepoChanged() {
    if (_drawing) return;
    _reloadDebouncer?.cancel();
    _reloadDebouncer = Timer(const Duration(milliseconds: 300), load);
  }

  // ---------- Load / select ----------

  /// Monotonically-increasing generation. Each [load] bumps it; only the
  /// most recent invocation publishes its result, so overlapping loads
  /// from rapid `userId` changes or repo events can't leave the controller
  /// in a stale state.
  int _loadGeneration = 0;

  Future<void> load() async {
    final generation = ++_loadGeneration;
    _loading = true;
    notifyListeners();
    final routes = await _repo.getAllRoutes();
    if (generation != _loadGeneration) return;
    _routes = routes;
    if (_routes.isEmpty) {
      // After clearUserData (e.g. sign-out) the repo can return an empty
      // list while `_selected` still points to a now-deleted route. Bail
      // out cleanly instead of crashing on `_routes.first`.
      _selected = null;
    } else {
      _selected ??= _routes.first;
      _selected = _routes.firstWhere(
        (r) => r.id == _selected!.id,
        orElse: () => _routes.first,
      );
    }
    _loading = false;
    notifyListeners();
    if (_selected != null) {
      _loadSessionsForRoute(_selected!.id);
    }
    _loadAllRouteSummaries();
  }

  void select(RouteTemplate route) {
    _selected = route;
    notifyListeners();
    _loadSessionsForRoute(route.id);
  }

  Future<void> _loadSessionsForRoute(String routeId) async {
    _sessionsForSelected = await _repo.getSessionsByRoute(routeId);
    notifyListeners();
  }

  Future<void> _loadAllRouteSummaries() async {
    final counts = <String, int>{};
    final bests = <String, Duration?>{};
    for (final route in _routes) {
      final sessions = await _repo.getSessionsByRoute(route.id);
      counts[route.id] = sessions.length;
      LapSummary? best;
      for (final s in sessions) {
        final lap = s.bestLap;
        if (lap != null && (best == null || lap.duration < best.duration)) {
          best = lap;
        }
      }
      bests[route.id] = best?.duration;
    }
    _routeSessionCounts = counts;
    _routeBestLaps = bests;
    notifyListeners();
  }

  // ---------- Draw mode lifecycle ----------

  void startDrawing({
    required String name,
    String? description,
    required RouteDifficulty difficulty,
  }) {
    _cancelSnap();
    _drawing = true;
    _snapFailure = null;
    _draftName = name;
    _draftDescription = description;
    _draftDifficulty = difficulty;
    _segments.clear();
    _draftSectorGates.clear();
    _draftSectorPoints.clear();
    _undoStack.clear();
    _inputMode = DrawInputMode.appendPath;
    _routingProfile = _defaultRoutingProfile;
    notifyListeners();
  }

  void cancelDrawing() {
    _cancelSnap();
    _drawing = false;
    _snapFailure = null;
    _draftName = '';
    _draftDescription = null;
    _draftDifficulty = RouteDifficulty.medium;
    _segments.clear();
    _activeFreehand = null;
    _draftSectorGates.clear();
    _draftSectorPoints.clear();
    _undoStack.clear();
    _inputMode = DrawInputMode.appendPath;
    _routingProfile = _defaultRoutingProfile;
    notifyListeners();
  }

  void setInputMode(DrawInputMode mode) {
    _inputMode = mode;
    notifyListeners();
  }

  void undoLastAction() {
    if (_undoStack.isEmpty) return;
    _cancelSnap();
    final op = _undoStack.removeLast();
    switch (op) {
      case _UndoOp.sector:
        if (_draftSectorPoints.isNotEmpty) _draftSectorPoints.removeLast();
        if (_draftSectorGates.isNotEmpty) _draftSectorGates.removeLast();
      case _UndoOp.pathPoint:
        if (_segments.isEmpty) break;
        final last = _segments.last;
        switch (last) {
          case FreehandSegment():
            _segments.removeLast();
          case SnappedSegment():
            if (last.waypoints.isNotEmpty) {
              last.waypoints.removeLast();
              last.snappedPath
                ..clear()
                ..addAll(last.effectiveWaypoints);
            }
            if (last.waypoints.isEmpty) {
              _segments.removeLast();
            } else if (last.effectiveWaypoints.length >= 2 &&
                routingService != null) {
              _scheduleSnap();
            }
        }
    }
    notifyListeners();
  }

  /// Routes a single map tap to the right drafting bucket.
  void handleMapTap(GeoPoint p) {
    if (!_drawing) return;
    switch (_inputMode) {
      case DrawInputMode.freehand:
        return;
      case DrawInputMode.appendPath:
        final lastSeg = _segments.lastOrNull;
        final SnappedSegment seg;
        if (lastSeg is SnappedSegment) {
          seg = lastSeg;
        } else {
          seg = SnappedSegment(seedPoint: lastSeg?.renderedPath.lastOrNull);
          _segments.add(seg);
        }
        seg.waypoints.add(p);
        seg.snappedPath
          ..clear()
          ..addAll(seg.effectiveWaypoints);
        _undoStack.add(_UndoOp.pathPoint);
        notifyListeners();
        _scheduleSnap();
      case DrawInputMode.sectorPoint:
        if (draftPath.length < 2) return;
        final dp = draftPath;
        final idx = _nearestPathIndex(dp, p);
        final snapped = dp[idx];
        if (snapped.distanceTo(p) > _sectorSnapMaxDistanceMeters) return;
        final gate = _gateAtPathIndex(dp, idx);
        _draftSectorPoints.add(snapped);
        _draftSectorGates.add(gate);
        _undoStack.add(_UndoOp.sector);
        notifyListeners();
    }
  }

  // ---------- Freehand handlers ----------

  FreehandSegment? _activeFreehand;

  void startFreehandStroke() {
    if (!_drawing) return;
    final seg = FreehandSegment();
    if (_segments.isNotEmpty) {
      final prev = _segments.last.renderedPath;
      if (prev.isNotEmpty) {
        seg.rawPoints.add(prev.last);
      }
    }
    _segments.add(seg);
    _activeFreehand = seg;
    notifyListeners();
  }

  void addFreehandPoint(GeoPoint p) {
    final seg = _activeFreehand;
    if (seg == null) return;
    if (seg.rawPoints.isNotEmpty && seg.rawPoints.last.distanceTo(p) < 5.0) {
      return;
    }
    seg.rawPoints.add(p);
    notifyListeners();
  }

  void endFreehandStroke() {
    final seg = _activeFreehand;
    if (seg == null) return;
    _activeFreehand = null;
    if (seg.rawPoints.length < 2) {
      _segments.remove(seg);
      notifyListeners();
      return;
    }
    seg.simplifiedPoints
      ..clear()
      ..addAll(simplifyPath(seg.rawPoints, 4.0));
    _undoStack.add(_UndoOp.pathPoint);
    notifyListeners();
  }

  // ---------- Sector-point helpers ----------

  /// Returns the index of the [path] vertex closest to [tap].
  int _nearestPathIndex(List<GeoPoint> path, GeoPoint tap) {
    int bestIdx = 0;
    double bestDist = path[0].distanceTo(tap);
    for (var i = 1; i < path.length; i++) {
      final d = path[i].distanceTo(tap);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// Builds a perpendicular [GateDefinition] at [path[idx]].
  GateDefinition _gateAtPathIndex(List<GeoPoint> path, int idx) {
    final anchor = path[idx];
    if (idx < path.length - 1) {
      return _perpendicularGate(anchor, path[idx + 1]);
    }
    // At the last vertex: extrapolate the bearing forward to keep the gate
    // centered on anchor (not on the previous vertex).
    final prev = path[idx - 1];
    final bearing = prev.bearingTo(anchor);
    final reference = anchor.destinationPoint(bearing, 1.0);
    return _perpendicularGate(anchor, reference);
  }

  // ---------- Live snap helpers ----------

  /// Cancels any pending debounce timer and in-flight snap request.
  void _cancelSnap() {
    _snapDebouncer?.cancel();
    _snapDebouncer = null;
    _snapGeneration++;   // invalidates any in-flight response
    _snapping = false;
  }

  /// Schedules a snap request to fire after 600 ms of inactivity.
  void _scheduleSnap() {
    final seg = _segments.lastOrNull;
    if (routingService == null || seg is! SnappedSegment || seg.effectiveWaypoints.length < 2) return;
    _snapDebouncer?.cancel();
    _snapDebouncer = Timer(const Duration(milliseconds: 600), _snapPath);
  }

  Future<void> _snapPath() async {
    if (routingService == null) return;
    final seg = _segments.lastOrNull;
    if (seg is! SnappedSegment) return;
    final effective = seg.effectiveWaypoints;
    if (effective.length < 2) return;

    final waypoints = List<GeoPoint>.of(effective);
    final generation = ++_snapGeneration;

    _snapping = true;
    notifyListeners();

    final result = await routingService!
        .snapToRoads(waypoints, profile: _routingProfile);

    if (_snapGeneration != generation) return;

    _snapping = false;
    final snapped = result.path;
    if (result.isSuccess && snapped != null && snapped.length >= 2) {
      _snapFailure = null;
      seg.snappedPath
        ..clear()
        ..addAll(snapped);
    } else {
      _snapFailure = result.failure?.reason ?? RoutingFailureReason.network;
      seg.snappedPath
        ..clear()
        ..addAll(waypoints);
    }
    notifyListeners();
  }

  // ---------- Save ----------

  Future<RouteTemplate?> saveDraft() async {
    if (!draftCanSave) return null;
    _cancelSnap();

    final pathParts = <List<GeoPoint>>[];
    var expectedTotal = Duration.zero;
    var expectedComplete = true;

    for (final seg in _segments) {
      switch (seg) {
        case SnappedSegment():
          final effective = seg.effectiveWaypoints;
          if (effective.isEmpty) continue;
          if (routingService != null && effective.length >= 2) {
            _snapping = true;
            notifyListeners();
            final result = await routingService!.snapToRoads(
              effective,
              profile: _routingProfile,
            );
            _snapping = false;
            notifyListeners();
            pathParts.add(result.path ?? effective);
            if (result.duration != null) {
              expectedTotal += result.duration!;
            } else {
              expectedComplete = false;
            }
          } else {
            pathParts.add(effective);
            expectedComplete = false;
          }
        case FreehandSegment():
          if (seg.simplifiedPoints.isNotEmpty) {
            pathParts.add(List.of(seg.simplifiedPoints));
          } else if (seg.rawPoints.isNotEmpty) {
            pathParts.add(List.of(seg.rawPoints));
          }
          expectedComplete = false;
      }
    }

    final finalPath = <GeoPoint>[];
    for (final part in pathParts) {
      if (part.isEmpty) continue;
      if (finalPath.isNotEmpty && part.isNotEmpty &&
          finalPath.last.distanceTo(part.first) < 1.0) {
        finalPath.addAll(part.skip(1));
      } else {
        finalPath.addAll(part);
      }
    }

    if (finalPath.length < 2) return null;

    Duration? expectedDuration;
    if (expectedComplete && expectedTotal > Duration.zero) {
      expectedDuration = expectedTotal;
    } else if (routingService != null) {
      // Save is a one-shot user-visible action, so retry on rate limits.
      final r = await routingService!.matchDuration(
        finalPath,
        profile: _routingProfile,
        maxRateLimitRetries: 2,
      );
      expectedDuration = r.duration;
    }

    final distFirstLast = finalPath.first.distanceTo(finalPath.last);
    final isClosed = distFirstLast <= 20.0;

    if (isClosed && finalPath.first != finalPath.last) {
      finalPath.add(finalPath.first);
    }

    debugPrint(
        'Route: ${isClosed ? "closed" : "open"} circuit, '
        'distance first↔last = ${distFirstLast.toStringAsFixed(1)} m');

    String? locationLabel;
    if (geocodingService != null && finalPath.isNotEmpty) {
      locationLabel = await geocodingService!.reverseGeocode(finalPath.first);
    }

    if (elevationService != null) {
      final enriched = await elevationService!.enrich(finalPath);
      finalPath
        ..clear()
        ..addAll(enriched);
    }

    final startFinishGate = _perpendicularGate(finalPath[0], finalPath[1]);

    double? elevMin;
    double? elevMax;
    for (final p in finalPath) {
      final alt = p.altitudeMeters;
      if (alt == null) continue;
      if (elevMin == null || alt < elevMin) elevMin = alt;
      if (elevMax == null || alt > elevMax) elevMax = alt;
    }
    final elevationRange = (elevMin != null && elevMax != null)
        ? elevMax - elevMin
        : null;

    final id = const Uuid().v4();
    final route = RouteTemplate(
      id: id,
      name: _draftName.trim(),
      description: _draftDescription?.trim().isEmpty ?? true
          ? null
          : _draftDescription!.trim(),
      locationLabel: locationLabel,
      path: List.unmodifiable(finalPath),
      startFinishGate: startFinishGate,
      sectors: () {
        // Sort sectors by position along the route, not by placement order.
        final sortedIndices =
            List.generate(_draftSectorGates.length, (i) => i)
              ..sort((a, b) {
                final idxA =
                    _nearestPathIndex(finalPath, _draftSectorPoints[a]);
                final idxB =
                    _nearestPathIndex(finalPath, _draftSectorPoints[b]);
                return idxA.compareTo(idxB);
              });
        return [
          for (var i = 0; i < sortedIndices.length; i++)
            SectorDefinition(
              id: const Uuid().v4(),
              order: i,
              label: 'Sector ${i + 1}',
              gate: _draftSectorGates[sortedIndices[i]],
            ),
        ];
      }(),
      difficulty: _draftDifficulty,
      createdAt: DateTime.now(),
      elevationRangeMeters: elevationRange,
      expectedDuration: expectedDuration,
    );

    await _repo.saveRouteTemplate(route);

    _drawing = false;
    _draftName = '';
    _draftDescription = null;
    _draftDifficulty = RouteDifficulty.medium;
    _segments.clear();
    _draftSectorGates.clear();
    _draftSectorPoints.clear();
    _undoStack.clear();
    _inputMode = DrawInputMode.appendPath;
    _routingProfile = _defaultRoutingProfile;
    _activeFreehand = null;

    await load();
    _selected = route;
    notifyListeners();
    return route;
  }

  /// Builds a [GateDefinition] perpendicular to the direction [anchor]→[next],
  /// centred on [anchor], with a half-width of 15 m each side (30 m total).
  static GateDefinition _perpendicularGate(GeoPoint anchor, GeoPoint next) {
    const halfWidth = 15.0;
    final fwdBearing = anchor.bearingTo(next);
    final left =
        anchor.destinationPoint((fwdBearing - 90 + 360) % 360, halfWidth);
    final right = anchor.destinationPoint((fwdBearing + 90) % 360, halfWidth);
    return GateDefinition(left: left, right: right);
  }

  // ---------- CRUD on existing routes ----------

  Future<void> deleteRoute(String id) async {
    // Official routes are not owned by the user. Going through the sync
    // service would attempt a remote DELETE that RLS rejects; instead we
    // dismiss them via OfficialRoutesService, which tombstones the local
    // row against the route's current `updated_at`.
    final existing = await _repo.getRouteTemplate(id);
    if (existing != null && existing.isOfficial) {
      if (officialRoutesService != null) {
        await officialRoutesService!.dismiss(id);
      } else {
        await _repo.deleteRoute(id);
      }
    } else if (syncService != null) {
      await syncService!.deleteRoute(id);
    } else {
      await _repo.deleteRoute(id);
    }
    if (_selected?.id == id) {
      _selected = null;
    }
    await load();
  }

  /// Lazily fills a route's Mapbox "normal time" when it's missing and the
  /// routing service is available (e.g. the route was created offline).
  Future<void> recomputeExpectedDuration(String routeId) async {
    final svc = routingService;
    if (svc == null) return;
    RouteTemplate? found;
    for (final r in _routes) {
      if (r.id == routeId) {
        found = r;
        break;
      }
    }
    if (found == null || found.expectedDuration != null) return;
    if (found.path.length < 2) return;
    // Lazy recompute — user just opened the detail. Retry on 429 so a single
    // rate-limit blip doesn't leave "normal time" empty forever.
    final r = await svc.matchDuration(
      found.path,
      profile: _defaultRoutingProfile,
      maxRateLimitRetries: 2,
    );
    if (r.duration == null) return;
    await _repo.updateRouteExpectedDuration(routeId, r.duration!);
    await load();
  }

  Future<void> updateRouteMetadata({
    required String routeId,
    required String name,
    String? description,
    required RouteDifficulty difficulty,
  }) async {
    final existing = _routes.firstWhere((r) => r.id == routeId);
    final updated = existing.copyWith(
      name: name,
      description: description,
      difficulty: difficulty,
    );
    await _repo.saveRouteTemplate(updated);
    await load();
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    _snapDebouncer?.cancel();
    _reloadDebouncer?.cancel();
    super.dispose();
  }
}
