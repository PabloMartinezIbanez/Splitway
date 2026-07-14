// movile_app/lib/src/features/free_ride/free_ride_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:splitway_core/splitway_core.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/local_draft_repository.dart';
import '../../services/geocoding/reverse_geocoding_service.dart';
import '../../services/routing/routing_service.dart';
import '../../services/sensors/device_heading_service.dart';
import '../../services/tracking/background_tracking_service.dart';
import '../../services/tracking/location_service.dart';

enum FreeRideStage { idle, recording, paused, finished }

class FreeRideController extends ChangeNotifier {
  FreeRideController(
    this._repo, {
    this.geocodingService,
    this.routingService,
    DeviceHeadingService? headingService,
  }) : _headingService = headingService ?? DeviceHeadingService();

  final LocalDraftRepository _repo;
  final ReverseGeocodingService? geocodingService;
  final RoutingService? routingService;
  final DeviceHeadingService _headingService;
  StreamSubscription<double>? _headingSub;

  FreeRideStage _stage = FreeRideStage.idle;
  FreeRideStage get stage => _stage;

  FreeRideEngine? _engine;
  FreeRideEngine? get engine => _engine;

  FreeRideRun? _result;
  FreeRideRun? get result => _result;

  LocationPermissionStatus? _permissionStatus;
  LocationPermissionStatus? get permissionStatus => _permissionStatus;

  String? _selectedVehicleId;
  String? get selectedVehicleId => _selectedVehicleId;

  String? _sessionName;
  String? get sessionName => _sessionName;

  bool _backgroundActive = false;
  bool get backgroundActive => _backgroundActive;

  void selectVehicle(String? vehicleId) {
    _selectedVehicleId = vehicleId;
    notifyListeners();
  }

  /// User-provided name for the ride being recorded. Blank input clears it
  /// so the ride falls back to the localized default label.
  void setSessionName(String? name) {
    final trimmed = name?.trim();
    _sessionName = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    notifyListeners();
  }

  StreamSubscription<TelemetryPoint>? _gpsSub;
  Timer? _ticker;

  final List<TelemetryPoint> _ingested = [];
  List<TelemetryPoint> get ingested => List.unmodifiable(_ingested);

  FreeRideSnapshot get snapshot =>
      _engine?.snapshot ?? FreeRideSnapshot.initial;

  int _distanceFilterMeters = 0;

  /// When false (recording in a motorized vehicle) the compass /
  /// accelerometer sensors are never started and the camera bearing comes
  /// from the GPS course alone.
  bool _useCompassHeading = true;

  /// Last GPS-derived course we've seen this ride. Used in the motorized
  /// path to freeze the camera bearing when the vehicle stops (GPS course
  /// becomes unreliable at standstill), instead of leaving the map without
  /// a bearing. Non-motorized rides keep using the compass at low speed.
  double? _lastGpsCourseDeg;

  DateTime? _recordingStartedAt;
  DateTime? _pausedAt;
  Duration _accumulatedElapsed = Duration.zero;

  /// Wall-clock elapsed time since recording started, freezing while paused.
  Duration get currentElapsed {
    final started = _recordingStartedAt;
    if (started == null) return _accumulatedElapsed;
    if (_pausedAt != null) return _accumulatedElapsed;
    return _accumulatedElapsed + DateTime.now().difference(started);
  }

  Future<void> startRecording({
    int distanceFilterMeters = 0,
    bool backgroundActive = false,
    bool useCompassHeading = true,
  }) async {
    _permissionStatus = await LocationService.ensurePermission();
    if (_permissionStatus != LocationPermissionStatus.granted) {
      notifyListeners();
      return;
    }

    _backgroundActive = backgroundActive;
    _distanceFilterMeters = distanceFilterMeters;
    _useCompassHeading = useCompassHeading;
    _lastGpsCourseDeg = null;

    if (_backgroundActive) {
      await BackgroundTrackingService.startTracking(
        title: 'Splitway · Grabando ruta',
        body: '0.0 km · 00:00:00',
      );
    }

    final id = 'fr-${DateTime.now().microsecondsSinceEpoch}';
    _engine = FreeRideEngine(sessionId: id);
    _engine!.start();
    _ingested.clear();
    _stage = FreeRideStage.recording;
    _recordingStartedAt = DateTime.now();
    _pausedAt = null;
    _accumulatedElapsed = Duration.zero;
    notifyListeners();

    _subscribeToGps();
    _subscribeToHeading();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_backgroundActive) {
        final snap = snapshot;
        final distKm = (snap.totalDistanceMeters / 1000).toStringAsFixed(1);
        BackgroundTrackingService.updateNotification(
          distance: '$distKm km',
          time: _formatElapsed(currentElapsed),
        );
      }
      notifyListeners();
    });
  }

  void _subscribeToGps() {
    _gpsSub = LocationService.positionStream(
      distanceFilterMeters: _distanceFilterMeters,
      backgroundMode: _backgroundActive,
    ).listen((point) {
      ingestPoint(point);
    }, onError: (_) {
      // GPS error — keep recording what we have.
    });
  }

  void _subscribeToHeading() {
    if (!_useCompassHeading) return;
    _headingService.start();
    _headingSub?.cancel();
    _headingSub = _headingService.headingStream.listen((_) {
      // The fused bearing has changed — notify the UI so it can rotate the
      // map even when no new GPS sample has arrived.
      notifyListeners();
    });
  }

  void _unsubscribeFromHeading() {
    _headingSub?.cancel();
    _headingSub = null;
    _headingService.stop();
  }

  /// Pause an in-progress recording. GPS samples are dropped while paused
  /// and the wall-clock elapsed time freezes.
  void pauseRecording() {
    if (_stage != FreeRideStage.recording || _pausedAt != null) return;
    final now = DateTime.now();
    final started = _recordingStartedAt;
    if (started != null) {
      _accumulatedElapsed += now.difference(started);
    }
    _pausedAt = now;
    _stage = FreeRideStage.paused;
    _gpsSub?.cancel();
    _gpsSub = null;
    _unsubscribeFromHeading();
    notifyListeners();
  }

  /// Resume after a pause. GPS subscription restarts and the wall clock
  /// keeps counting from where it left off.
  void resumeRecording() {
    if (_stage != FreeRideStage.paused) return;
    _pausedAt = null;
    _recordingStartedAt = DateTime.now();
    _stage = FreeRideStage.recording;
    _subscribeToGps();
    _subscribeToHeading();
    notifyListeners();
  }

  /// Hot-upgrade from foreground-only to background tracking mid-recording.
  /// Called when the user grants 'always' permission via app settings and
  /// returns to the app.
  Future<void> upgradeToBackground() async {
    if (_backgroundActive || _stage != FreeRideStage.recording) return;

    final permission = await LocationService.ensureBackgroundPermission();
    if (permission != LocationPermissionStatus.granted) return;

    _backgroundActive = true;

    await BackgroundTrackingService.startTracking(
      title: 'Splitway · Grabando ruta',
      body: '0.0 km · 00:00:00',
    );

    // Restart the GPS stream with background mode enabled.
    await _gpsSub?.cancel();
    _gpsSub = LocationService.positionStream(
      distanceFilterMeters: _distanceFilterMeters,
      backgroundMode: true,
    ).listen((point) {
      ingestPoint(point);
    }, onError: (_) {});

    notifyListeners();
  }

  void ingestPoint(TelemetryPoint point) {
    if (_stage != FreeRideStage.recording) return;
    _engine?.ingest(point);
    _ingested.add(point);
    notifyListeners();
  }

  /// Latest known heading in degrees (0 = north, clockwise).
  ///
  /// In a motorized vehicle (phone mounted, [_useCompassHeading] false) the
  /// GPS course is used exclusively: current if available, last known
  /// otherwise, so the map keeps pointing forward when the user stops
  /// instead of spinning to wherever the phone's top edge points.
  ///
  /// On foot or by bike (phone hand-held, [_useCompassHeading] true) the
  /// magnetic compass is blended with the GPS course via [fusedBearingDeg]
  /// — compass wins at standstill so the map rotates as the user turns the
  /// device to look around, GPS wins above ~4 m/s.
  double? get currentBearingDeg {
    final gpsCourse = _gpsCourseDeg();
    if (!_useCompassHeading) return gpsCourse ?? _lastGpsCourseDeg;
    final compass = _headingService.currentHeadingDeg;
    final speed = _engine?.snapshot.currentSpeedMps ?? 0.0;
    return fusedBearingDeg(
      compassDeg: compass,
      gpsCourseDeg: gpsCourse,
      speedMps: speed,
    );
  }

  /// GPS-derived course (direction of travel) in degrees, or null when no
  /// reliable estimate is available. Uses the GPS-reported bearing when
  /// present; otherwise falls back to the bearing between the last two
  /// ingested points (only if they're more than 1 m apart, to avoid noise).
  /// Every non-null result is cached in [_lastGpsCourseDeg] so the camera
  /// can freeze on the last known direction while the vehicle is stopped.
  double? _gpsCourseDeg() {
    if (_ingested.isEmpty) return null;
    final last = _ingested.last;
    final reported = last.bearingDeg;
    if (reported != null && reported >= 0) {
      _lastGpsCourseDeg = reported;
      return reported;
    }
    if (_ingested.length < 2) return null;
    final prev = _ingested[_ingested.length - 2];
    if (prev.location.distanceTo(last.location) < 1.0) return null;
    final course = prev.location.bearingTo(last.location);
    _lastGpsCourseDeg = course;
    return course;
  }

  Future<FreeRideRun?> finishRecording({String routingProfile = 'driving'}) async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    _ticker?.cancel();
    _ticker = null;
    _unsubscribeFromHeading();

    if (_backgroundActive) {
      await BackgroundTrackingService.stopTracking();
      _backgroundActive = false;
    }

    final e = _engine;
    if (e == null) return null;
    final raw = e.finish();

    // Reverse-geocode the start point so the free ride has a location label.
    String? locationLabel;
    if (geocodingService != null && raw.points.isNotEmpty) {
      locationLabel =
          await geocodingService!.reverseGeocode(raw.points.first.location);
    }

    var run = raw.copyWith(
      name: _sessionName,
      vehicleId: _selectedVehicleId,
      locationLabel: locationLabel,
    );

    // Mapbox "normal time" for the recorded path. One Map Matching call; any
    // failure (offline, no token, no match, <2 points) leaves it null and the
    // ride is saved anyway. Recomputed lazily when the detail screen opens.
    // Retry on rate-limits — a saved ride's "normal time" is worth waiting for.
    final svc = routingService;
    if (svc != null && run.points.length >= 2) {
      final r = await svc.matchDuration(
        run.path,
        profile: routingProfile,
        maxRateLimitRetries: 2,
      );
      if (r.duration != null) {
        run = run.copyWith(expectedDuration: r.duration);
      }
    }

    await _repo.saveFreeRideRun(run);
    _result = run;
    _stage = FreeRideStage.finished;
    notifyListeners();
    return run;
  }

  Future<RouteTemplate?> saveAsRoute({
    required String name,
    String? description,
    RouteDifficulty difficulty = RouteDifficulty.medium,
    String? locationLabel,
  }) async {
    final run = _result;
    if (run == null || run.points.length < 2) return null;

    final path = run.points.map((p) => p.location).toList();
    final simplified =
        path.length > 200 ? simplifyPath(path, 5.0) : path;

    final gate = GateDefinition(
      left: simplified.first.destinationPoint(
        (simplified.first.bearingTo(simplified[1]) + 90) % 360,
        10,
      ),
      right: simplified.first.destinationPoint(
        (simplified.first.bearingTo(simplified[1]) - 90 + 360) % 360,
        10,
      ),
    );

    // Resolve location: use provided label, fall back to run's label, then geocode.
    String? resolvedLocation = locationLabel ?? run.locationLabel;
    if (resolvedLocation == null && geocodingService != null && simplified.isNotEmpty) {
      resolvedLocation = await geocodingService!.reverseGeocode(simplified.first);
    }

    final route = RouteTemplate(
      id: const Uuid().v4(),
      name: name,
      description: description,
      path: simplified,
      startFinishGate: gate,
      sectors: const [],
      difficulty: difficulty,
      createdAt: DateTime.now(),
      locationLabel: resolvedLocation,
      elevationRangeMeters: run.elevationRangeMeters,
      expectedDuration: run.expectedDuration,
    );

    await _repo.saveRouteTemplate(route);

    // Create a lap summary so the route detail shows the free ride duration as best time.
    final endedAt = run.endedAt ?? DateTime.now();
    final rideDuration = endedAt.difference(run.startedAt);
    final lap = LapSummary(
      lapNumber: 1,
      duration: rideDuration,
      startedAt: run.startedAt,
      endedAt: endedAt,
      distanceMeters: run.totalDistanceMeters,
      avgSpeedMps: run.avgSpeedMps,
      completed: true,
    );

    final session = SessionRun(
      id: const Uuid().v4(),
      routeTemplateId: route.id,
      startedAt: run.startedAt,
      endedAt: run.endedAt,
      status: SessionStatus.completed,
      points: run.points,
      laps: [lap],
      sectorSummaries: const [],
      totalDistanceMeters: run.totalDistanceMeters,
      maxSpeedMps: run.maxSpeedMps,
      avgSpeedMps: run.avgSpeedMps,
      vehicleId: run.vehicleId,
    );
    await _repo.saveSessionRun(session);

    await _repo.deleteFreeRide(run.id);

    return route;
  }

  void resetForNewRide() {
    _engine = null;
    _result = null;
    _sessionName = null;
    _ingested.clear();
    _permissionStatus = null;
    _backgroundActive = false;
    _recordingStartedAt = null;
    _pausedAt = null;
    _accumulatedElapsed = Duration.zero;
    _stage = FreeRideStage.idle;
    notifyListeners();
  }

  static String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _ticker?.cancel();
    _headingSub?.cancel();
    _headingService.dispose();
    if (_backgroundActive) {
      BackgroundTrackingService.stopTracking();
    }
    super.dispose();
  }
}
