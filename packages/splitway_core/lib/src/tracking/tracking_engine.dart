import 'dart:async';

import '../models/lap_summary.dart';
import '../models/route_template.dart';
import '../models/sector_definition.dart';
import '../models/sector_summary.dart';
import '../models/session_run.dart';
import '../models/telemetry_point.dart';
import '../models/tracking_snapshot.dart';

sealed class TrackingEvent {
  const TrackingEvent(this.at);
  final DateTime at;
}

class TrackingStarted extends TrackingEvent {
  const TrackingStarted(super.at);
}

class SectorCrossed extends TrackingEvent {
  const SectorCrossed({
    required DateTime at,
    required this.sectorId,
    required this.lapNumber,
    required this.duration,
  }) : super(at);

  final String sectorId;
  final int lapNumber;
  final Duration duration;
}

class LapClosed extends TrackingEvent {
  const LapClosed({
    required DateTime at,
    required this.lap,
  }) : super(at);

  final LapSummary lap;
}

class TrackingFinished extends TrackingEvent {
  const TrackingFinished(super.at);
}

class TrackingEngine {
  TrackingEngine({
    required RouteTemplate route,
    required String sessionId,
    DateTime Function()? clock,
  })  : _route = route,
        _sessionId = sessionId,
        _clock = clock ?? DateTime.now;

  final RouteTemplate _route;
  final String _sessionId;
  final DateTime Function() _clock;

  final StreamController<TrackingEvent> _events =
      StreamController<TrackingEvent>.broadcast();
  Stream<TrackingEvent> get events => _events.stream;

  final List<TelemetryPoint> _points = [];
  final List<LapSummary> _laps = [];
  final List<SectorSummary> _sectorSummaries = [];

  TrackingStatus _status = TrackingStatus.idle;
  TelemetryPoint? _previous;
  DateTime? _lapStartedAt;
  DateTime? _lastSectorAt;
  int _currentLap = 0;
  int _nextSectorIndex = 0;
  double _totalDistanceMeters = 0;
  double _maxSpeedMps = 0;
  double _lastSpeedMps = 0;
  double _lapDistanceAccumulator = 0;
  double _sectorDistanceAccumulator = 0;
  Duration? _bestLap;
  DateTime? _lastCrossingAt;
  DateTime? _finishedAt;
  String? _lastCrossedSectorId;
  Duration? _lastSectorTime;

  /// Minimum time between two recognised start/finish crossings.
  /// Prevents double-counting from GPS noise or rapid simulation steps.
  static const _crossingCooldown = Duration(seconds: 3);

  /// Maximum distance (in meters) from the last path point to trigger
  /// an automatic finish on open (non-closed) routes.
  static const _finishProximityMeters = 20.0;

  /// Minimum distance (in meters) an incomplete lap must cover to be saved.
  /// Prevents recording a phantom lap when the session ends right after
  /// crossing the start/finish gate.
  static const _minIncompleteLapMeters = 50.0;

  static const _gapThreshold = Duration(seconds: 5);
  static const _recoveryDuration = Duration(seconds: 3);
  DateTime? _recoveringUntil;

  /// All sector crossings recorded so far this session, across every lap.
  /// Ordered by crossing time. Read-only view for live/historical coloring.
  List<SectorSummary> get sectorSummaries => List.unmodifiable(_sectorSummaries);

  /// Telemetry recorded during the active route — between the first start/finish
  /// crossing (status `inLap`) and the finish. Points ingested before the first
  /// crossing, or after the route finishes, drive crossing detection but are
  /// never stored. This is what the live view and the saved history draw.
  List<TelemetryPoint> get recordedPoints => List.unmodifiable(_points);

  TrackingSnapshot get snapshot {
    final lapElapsed = _lapStartedAt == null
        ? Duration.zero
        : _clock().difference(_lapStartedAt!);
    return TrackingSnapshot(
      status: _status,
      currentLap: _currentLap,
      currentLapElapsed: lapElapsed,
      totalDistanceMeters: _totalDistanceMeters,
      lastSpeedMps: _lastSpeedMps,
      lastCrossedSectorId: _lastCrossedSectorId,
      lastSectorTime: _lastSectorTime,
      bestLap: _bestLap,
    );
  }

  /// Begins tracking. The next ingested point is the baseline; the first
  /// crossing of the start/finish gate opens lap 1.
  void start() {
    if (_status != TrackingStatus.idle) return;
    _status = TrackingStatus.awaitingStart;
    _lastCrossingAt = null;   // ensure cooldown does not carry over on engine reuse
  }

  void ingest(TelemetryPoint point) {
    if (_status == TrackingStatus.idle ||
        _status == TrackingStatus.finished) {
      return;
    }
    // Only store telemetry that belongs to the active route. Points ingested
    // while `awaitingStart` (before the first node — including the gate-crossing
    // point itself, since the status flips to inLap only after this guard) are
    // skipped here; points ingested after the route finishes are skipped by the
    // early-return at the top of ingest. They are still processed for crossing
    // detection / metrics, so only storage — the drawn + saved trail — is
    // trimmed to start at the first node and stop at the finish.
    if (_status == TrackingStatus.inLap) {
      _points.add(point);
    }

    // Speed is a per-sample value — update it on every ingest so the live
    // display tracks the GPS-reported speed instantly, regardless of gap
    // detection state.
    _lastSpeedMps = point.speedMps ?? _lastSpeedMps;
    if ((point.speedMps ?? 0) > _maxSpeedMps) {
      _maxSpeedMps = point.speedMps!;
    }

    final prev = _previous;
    if (prev == null) {
      _previous = point;
      return;
    }

    if (point.timestamp.difference(prev.timestamp) >= _gapThreshold) {
      _recoveringUntil = point.timestamp.add(_recoveryDuration);
      _previous = point;
      return;
    }

    if (_recoveringUntil != null) {
      if (point.timestamp.isBefore(_recoveringUntil!)) {
        _previous = point;
        return;
      }
      _recoveringUntil = null;
    }

    final stepDistance = prev.location.distanceTo(point.location);
    _totalDistanceMeters += stepDistance;
    _lapDistanceAccumulator += stepDistance;
    _sectorDistanceAccumulator += stepDistance;

    if (_route.startFinishGate.crossedBy(prev.location, point.location)) {
      _onStartFinishCrossed(point.timestamp);
    } else if (_status == TrackingStatus.inLap &&
        _nextSectorIndex < _orderedSectors.length) {
      final sector = _orderedSectors[_nextSectorIndex];
      if (sector.gate.crossedBy(prev.location, point.location)) {
        _onSectorCrossed(sector, point.timestamp);
      }
    }

    // Open route finish: check proximity to the last path point.
    if (!_route.isClosed &&
        _status == TrackingStatus.inLap &&
        _route.path.length >= 2) {
      final finish = _route.path.last;
      if (point.location.distanceTo(finish) <= _finishProximityMeters) {
        _finishOpenRoute(point.timestamp);
      }
    }

    _previous = point;
  }

  /// Closes the current state and returns the recorded session.
  /// Safe to call multiple times — subsequent calls return the same snapshot.
  SessionRun finish() {
    if (_status == TrackingStatus.finished) {
      return _buildSession(endedAt: _finishedAt);
    }
    final endedAt = _clock();
    // Record an incomplete lap (open or closed route) only if enough distance
    // was covered. This avoids saving a phantom lap when the session ends right
    // after crossing the start/finish gate. Open routes that reach the finish
    // auto-finish first (status == finished, handled above), so this branch
    // only fires when the user stops before the end.
    if (_status == TrackingStatus.inLap &&
        _lapStartedAt != null &&
        _lapDistanceAccumulator >= _minIncompleteLapMeters) {
      _laps.add(_buildLap(
        endedAt: endedAt,
        completed: false,
      ));
    }
    _finishedAt = endedAt;
    _status = TrackingStatus.finished;
    _events.add(TrackingFinished(endedAt));
    return _buildSession(endedAt: endedAt);
  }

  Future<void> dispose() async {
    await _events.close();
  }

  // ---------- internals ----------

  List<SectorDefinition> get _orderedSectors {
    final list = [..._route.sectors]..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  void _onStartFinishCrossed(DateTime at) {
    // Cooldown: ignore crossings that arrive too soon after the previous one.
    final last = _lastCrossingAt;
    // Covers both too-soon crossings and out-of-order timestamps (negative difference).
    if (last != null && at.difference(last) < _crossingCooldown) return;
    _lastCrossingAt = at;

    if (_status == TrackingStatus.awaitingStart) {
      _status = TrackingStatus.inLap;
      _currentLap = 1;
      _lapStartedAt = at;
      _lastSectorAt = at;
      _nextSectorIndex = 0;
      _lapDistanceAccumulator = 0;
      _sectorDistanceAccumulator = 0;
      _events.add(TrackingStarted(at));
      return;
    }
    if (_status == TrackingStatus.inLap && _lapStartedAt != null) {
      // Open routes don't loop: ignore re-crossings of the start/finish gate.
      // Their single lap is closed when the route finishes (_finishOpenRoute).
      if (!_route.isClosed) return;

      // The lap closes at the start/finish line, which is also the end of the
      // implicit final sector (last gate → start/finish). Record it before the
      // lap so SectorCrossed precedes LapClosed.
      _recordFinalSector(at);
      final closed = _buildLap(endedAt: at, completed: true);
      _laps.add(closed);
      if (_bestLap == null || closed.duration < _bestLap!) {
        _bestLap = closed.duration;
      }
      _events.add(LapClosed(at: at, lap: closed));
      _currentLap += 1;
      _lapStartedAt = at;
      _lastSectorAt = at;
      _nextSectorIndex = 0;
      _lapDistanceAccumulator = 0;
      _sectorDistanceAccumulator = 0;
    }
  }

  /// Automatically finishes the session for open routes (e.g. when the rider
  /// reaches the last path point).
  void _finishOpenRoute(DateTime at) {
    // The last path point ends the implicit final sector (last gate → finish).
    _recordFinalSector(at);
    // The full traversal from the start gate to the finish is one completed
    // lap — record it so a finished open route reports 1 lap, not 0.
    if (_lapStartedAt != null) {
      final closed = _buildLap(endedAt: at, completed: true);
      _laps.add(closed);
      if (_bestLap == null || closed.duration < _bestLap!) {
        _bestLap = closed.duration;
      }
      _events.add(LapClosed(at: at, lap: closed));
    }
    _finishedAt = at;
    _status = TrackingStatus.finished;
    _events.add(TrackingFinished(at));
  }

  /// Records the implicit final sector — the segment from the last sector gate
  /// to the start/finish line (closed) or last path point (open). Only recorded
  /// when sectors are defined and every gate has been crossed this lap, so a lap
  /// that ends mid-sector is not counted.
  void _recordFinalSector(DateTime at) {
    if (_orderedSectors.isEmpty) return;
    if (_nextSectorIndex < _orderedSectors.length) return;
    final since = _lastSectorAt ?? _lapStartedAt ?? at;
    final duration = at.difference(since);
    final avgSpeed = duration.inMilliseconds == 0
        ? 0.0
        : _sectorDistanceAccumulator / (duration.inMilliseconds / 1000.0);
    final summary = SectorSummary(
      sectorId: kFinalSectorId,
      lapNumber: _currentLap,
      duration: duration,
      startedAt: since,
      endedAt: at,
      distanceMeters: _sectorDistanceAccumulator,
      avgSpeedMps: avgSpeed,
    );
    _sectorSummaries.add(summary);
    _lastCrossedSectorId = kFinalSectorId;
    _lastSectorTime = duration;
    _events.add(SectorCrossed(
      at: at,
      sectorId: kFinalSectorId,
      lapNumber: _currentLap,
      duration: duration,
    ));
  }

  void _onSectorCrossed(SectorDefinition sector, DateTime at) {
    final since = _lastSectorAt ?? _lapStartedAt ?? at;
    final duration = at.difference(since);
    final avgSpeed = duration.inMilliseconds == 0
        ? 0.0
        : _sectorDistanceAccumulator / (duration.inMilliseconds / 1000.0);
    final summary = SectorSummary(
      sectorId: sector.id,
      lapNumber: _currentLap,
      duration: duration,
      startedAt: since,
      endedAt: at,
      distanceMeters: _sectorDistanceAccumulator,
      avgSpeedMps: avgSpeed,
    );
    _sectorSummaries.add(summary);
    _lastCrossedSectorId = sector.id;
    _lastSectorTime = duration;
    _lastSectorAt = at;
    _sectorDistanceAccumulator = 0;
    _nextSectorIndex += 1;
    _events.add(SectorCrossed(
      at: at,
      sectorId: sector.id,
      lapNumber: _currentLap,
      duration: duration,
    ));
  }

  LapSummary _buildLap({required DateTime endedAt, required bool completed}) {
    final start = _lapStartedAt!;
    final duration = endedAt.difference(start);
    final avgSpeed = duration.inMilliseconds == 0
        ? 0.0
        : _lapDistanceAccumulator / (duration.inMilliseconds / 1000.0);
    return LapSummary(
      lapNumber: _currentLap,
      duration: duration,
      startedAt: start,
      endedAt: endedAt,
      distanceMeters: _lapDistanceAccumulator,
      avgSpeedMps: avgSpeed,
      completed: completed,
    );
  }

  SessionRun _buildSession({DateTime? endedAt}) {
    final firstTs = _points.isNotEmpty ? _points.first.timestamp : _clock();
    final lastTs = endedAt ?? (_points.isNotEmpty ? _points.last.timestamp : firstTs);
    final totalSeconds = lastTs.difference(firstTs).inMilliseconds / 1000.0;
    final avgSpeed =
        totalSeconds <= 0 ? 0.0 : _totalDistanceMeters / totalSeconds;
    return SessionRun(
      id: _sessionId,
      routeTemplateId: _route.id,
      startedAt: firstTs,
      endedAt: lastTs,
      status: SessionStatus.completed,
      points: List.unmodifiable(_points),
      laps: List.unmodifiable(_laps),
      sectorSummaries: List.unmodifiable(_sectorSummaries),
      totalDistanceMeters: _totalDistanceMeters,
      maxSpeedMps: _maxSpeedMps,
      avgSpeedMps: avgSpeed,
    );
  }
}
