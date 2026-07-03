import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:splitway_core/splitway_core.dart';

import '../../data/repositories/local_draft_repository.dart';
import '../../data/repositories/speed_repository.dart';
import '../../data/repositories/supabase_repository.dart';
import '../logging/app_logger.dart';
import 'sync_planner.dart';
import 'sync_remote.dart';

/// Bidirectional sync between [LocalDraftRepository] (SQLite) and
/// [SupabaseRepository] (Postgres + RLS).
///
/// Strategy: **last-write-wins** based on `updated_at`.
/// - Push: all local routes/sessions that don't exist remotely or are newer.
/// - Pull: all remote routes/sessions that don't exist locally or are newer.
///
/// Supports:
/// - Change-triggered auto-sync: a local write arms a debounce timer
///   ([autoSyncDebounce], default 1 min) that resets on each change, so a
///   burst of edits uploads together. Exposes [hasPendingChanges] for the UI.
/// - Periodic auto-sync every [syncInterval] (default 5 min).
/// - Connectivity awareness — pauses when offline, resumes when back online.
/// - Programmatic trigger via [sync()].
class SyncService extends ChangeNotifier {
  SyncService({
    required this.local,
    required this.remote,
    this.speedRepository,
    this.userId,
    this.syncInterval = const Duration(minutes: 5),
    this.autoSyncDebounce = const Duration(minutes: 1),
    Stream<List<ConnectivityResult>>? connectivityStream,
  }) {
    _connectivitySubscription =
        (connectivityStream ?? Connectivity().onConnectivityChanged)
            .listen(_onConnectivityChanged);
    _changesSubscription = local.changes.listen((_) => _onLocalChange());
  }

  final LocalDraftRepository local;
  final SyncRemote remote;
  final SpeedRepository? speedRepository;
  final String? userId;
  final Duration syncInterval;
  final Duration autoSyncDebounce;

  Timer? _periodicTimer;
  Timer? _autoSyncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<void>? _changesSubscription;
  bool _isConnected = true;
  bool _disposed = false;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  bool _hasPendingChanges = false;
  bool get hasPendingChanges => _hasPendingChanges;

  String? _lastError;
  String? get lastError => _lastError;

  DateTime? _lastSyncedAt;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Start the periodic sync timer. Call this after authentication succeeds.
  void startPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(syncInterval, (_) {
      if (_isConnected) sync();
    });
    // Do an initial sync immediately.
    if (_isConnected) sync();
  }

  /// Stop the periodic sync timer (e.g. on sign-out).
  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Deletes a route from both local storage and the remote backend.
  Future<void> deleteRoute(String id) async {
    await local.deleteRoute(id);
    try {
      await remote.deleteRoute(id);
    } catch (e, st) {
      debugPrint('SyncService: failed to delete route $id from remote: $e');
      AppLogger.maybeInstance?.warning(
        'sync',
        'deleteRoute remote failed',
        error: e,
        stackTrace: st,
        context: {'id': id},
      );
    }
  }

  /// Deletes a session from both local storage and the remote backend.
  Future<void> deleteSession(String id) async {
    await local.deleteSession(id);
    try {
      await remote.deleteSession(id);
    } catch (e, st) {
      debugPrint('SyncService: failed to delete session $id from remote: $e');
      AppLogger.maybeInstance?.warning(
        'sync',
        'deleteSession remote failed',
        error: e,
        stackTrace: st,
        context: {'id': id},
      );
    }
  }

  /// Deletes a free ride from both local storage and the remote backend.
  Future<void> deleteFreeRide(String id) async {
    await local.deleteFreeRide(id);
    try {
      await remote.deleteFreeRide(id);
    } catch (e, st) {
      debugPrint('SyncService: failed to delete free ride $id from remote: $e');
      AppLogger.maybeInstance?.warning(
        'sync',
        'deleteFreeRide remote failed',
        error: e,
        stackTrace: st,
        context: {'id': id},
      );
    }
  }

  /// Reacts to a local write. Writes that occur *while a sync is running* are
  /// typically the sync's own pull/thumbnail writes (they flow through the same
  /// [LocalDraftRepository.changes] stream), so they are ignored — this both
  /// avoids marking a false "pending" state and prevents a pull->re-sync loop.
  /// Any other write flags pending and (re)arms the debounce; the timer resets
  /// on each change so a burst of edits is uploaded together.
  ///
  /// Note: the "it's the sync's own write" assumption is a heuristic — a
  /// genuine user write that happens to land during an in-flight sync is
  /// dropped here too and won't be retried until the next periodic sync,
  /// connectivity change, or subsequent local change. Accepted as a rare,
  /// low-cost tradeoff.
  void _onLocalChange() {
    if (_status == SyncStatus.syncing) return;
    _hasPendingChanges = true;
    notifyListeners();
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(autoSyncDebounce, () {
      _autoSyncTimer = null;
      if (_isConnected) sync();
    });
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    _isConnected = results.any((r) => r != ConnectivityResult.none);

    if (_isConnected && !wasConnected) {
      // Back online — sync immediately.
      debugPrint('SyncService: back online, syncing…');
      _status = SyncStatus.idle;
      notifyListeners();
      sync();
    } else if (!_isConnected && wasConnected) {
      debugPrint('SyncService: went offline');
      _status = SyncStatus.offline;
      notifyListeners();
    }
  }

  /// Runs a full bidirectional sync.
  /// Returns the number of items transferred (pushed + pulled).
  Future<int> sync() async {
    if (_status == SyncStatus.syncing) return 0;
    if (!_isConnected) {
      _status = SyncStatus.offline;
      notifyListeners();
      return 0;
    }
    // Never sync without an authenticated session. When the session is lost
    // (e.g. a stale refresh token forced a signOut), requests would go out with
    // the anon key and RPCs like upsert_route_with_sectors reject anon with a
    // 42501, surfacing as a noisy "full sync failed". Skip silently, leaving
    // status and pending changes untouched so it retries once a session is back.
    if (!remote.hasSession) return 0;

    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();

    try {
      final transferred = await _doSync();
      _status = SyncStatus.success;
      _lastSyncedAt = DateTime.now();
      _hasPendingChanges = false;
      notifyListeners();
      return transferred;
    } catch (e, st) {
      debugPrint('SyncService error: $e\n$st');
      AppLogger.maybeInstance?.warning(
        'sync',
        'full sync failed',
        error: e,
        stackTrace: st,
      );
      _status = SyncStatus.error;
      _lastError = e.toString();
      notifyListeners();
      return 0;
    }
  }

  Future<int> _doSync() async {
    var transferred = 0;

    // --- Routes ---
    // Comparison uses only IDs + timestamps — no heavy path_json loading.
    final localRoutes = await local.getAllRoutes();
    final remoteRouteTs = await remote.fetchRouteTimestamps();

    // Push local → remote (new or newer locally, or missing thumbnail).
    // Collect routes with new thumbnails to batch-save locally afterwards,
    // so the controller's 300ms reload debouncer collapses all saves into
    // a single UI rebuild (avoids one flicker per thumbnail loaded).
    // Track which IDs are pushed so the reconciliation step below can
    // distinguish "new local route" from "route deleted in remote".
    final routesWithNewThumbnails = <RouteTemplate>[];
    final pushedRouteIds = <String>{};
    for (final route in localRoutes) {
      if (route.isOfficial) {
        // Official routes are owned by Splitway and curated via
        // OfficialRoutesService. Never push them or generate thumbnails
        // here — that is the official account's responsibility, and the
        // catalog fetch already brings the remote thumbnail URL.
        continue;
      }
      final remoteUpdated = remoteRouteTs[route.id];
      // Last-write-wins by updated_at (falling back to createdAt for legacy
      // rows without an updatedAt). Using updatedAt — not createdAt — is what
      // lets edits to an already-synced route propagate to other devices.
      final needsPush = SyncPlanner.shouldPush(
        localUpdatedAt: route.updatedAt ?? route.createdAt,
        remoteUpdatedAt: remoteUpdated,
      );
      final needsThumbnail = route.thumbnailUrl == null;
      if (needsPush || needsThumbnail) {
        final updated = await remote.upsertRoute(route);
        pushedRouteIds.add(route.id);
        if (updated.thumbnailUrl != null &&
            updated.thumbnailUrl != route.thumbnailUrl) {
          routesWithNewThumbnails.add(updated);
        }
        transferred++;
      }
    }
    // Batch-save: all local writes happen back-to-back (no network delay),
    // so the 300ms debouncer collapses them into one reload.
    for (final route in routesWithNewThumbnails) {
      await local.saveRouteTemplate(route);
    }

    // Reconcile: remove local non-official routes that no longer exist in
    // Supabase and were not pushed in this cycle (which would mean they
    // are newly created, not remotely deleted). Official routes are owned
    // by OfficialRoutesService and intentionally bypass this loop.
    //
    // Guard against a transient empty fetch wiping local data: if the remote
    // set is empty while we still hold local routes, skip deletions.
    final nonOfficialLocalCount =
        localRoutes.where((r) => !r.isOfficial).length;
    if (SyncPlanner.shouldApplyReconciliationDeletions(
      remoteCount: remoteRouteTs.length,
      localCount: nonOfficialLocalCount,
    )) {
      for (final route in localRoutes) {
        if (route.isOfficial) continue;
        if (pushedRouteIds.contains(route.id)) continue;
        if (!remoteRouteTs.containsKey(route.id)) {
          await local.deleteRoute(route.id);
        }
      }
    }

    // Pull remote → local: save routes missing locally OR whose remote copy
    // is newer than the local one (so edits made on another device land
    // here). Routes pushed this cycle are skipped — local is authoritative
    // for those. Supabase RLS scopes results to the current user.
    final localRouteById = {for (final r in localRoutes) r.id: r};
    final remoteRoutes = await remote.fetchAllRoutes();
    for (final route in remoteRoutes) {
      if (pushedRouteIds.contains(route.id)) continue;
      final localRoute = localRouteById[route.id];
      final shouldPull = SyncPlanner.shouldPull(
        localUpdatedAt: localRoute?.updatedAt ?? localRoute?.createdAt,
        remoteUpdatedAt: route.updatedAt ?? route.createdAt,
      );
      if (shouldPull) {
        await local.saveRouteTemplate(route);
        transferred++;
      }
    }

    // --- Sessions ---
    // Load local sessions WITHOUT telemetry — only need IDs + timestamps
    // to decide what to push/pull.
    final localSessions = await local.getAllSessions(includePoints: false);
    final remoteSessionTs = await remote.fetchSessionTimestamps();

    // Route ids guaranteed to satisfy session_runs.route_id's FK: everything
    // already on the remote plus everything pushed this cycle.
    final remoteRouteIds = <String>{...remoteRouteTs.keys, ...pushedRouteIds};

    // Push local → remote (new or newer locally).
    // Re-load each session WITH points only when we actually need to push.
    for (final session in localSessions) {
      if (!SyncPlanner.canPushSession(
        routeId: session.routeTemplateId,
        remoteRouteIds: remoteRouteIds,
      )) {
        // Route not present remotely (e.g. an unpublished official route).
        // Skipping avoids a 23503 FK violation that would otherwise abort the
        // whole sync; the session syncs once its route appears remotely.
        //
        // Capture the local route's state so the log is conclusive about WHY:
        //  - isOfficial == true  → an official route missing server-side
        //    (curator deleted/never published it); nothing the client can fix.
        //  - isOfficial == false → a user route that should have been pushed
        //    this cycle but wasn't — a real sync gap, not just a stale catalog.
        //  - null                → no locally-visible route for this id.
        final route = await local.getRouteTemplate(session.routeTemplateId);
        AppLogger.maybeInstance?.warning(
          'sync',
          'Skipping session push: route absent remotely '
              '(would violate session_runs_route_id_fkey)',
          context: {
            'session_id': session.id,
            'route_id': session.routeTemplateId,
            'route_exists_locally': route != null,
            'route_is_official': route?.isOfficial,
          },
        );
        continue;
      }
      final remoteUpdated = remoteSessionTs[session.id];
      // Sessions are versioned by endedAt (no separate updatedAt column).
      if (SyncPlanner.shouldPush(
        localUpdatedAt: session.endedAt,
        remoteUpdatedAt: remoteUpdated,
      )) {
        final full = await local.getSessionRun(session.id);
        if (full != null) {
          await remote.upsertSession(full);
          transferred++;
        }
      }
    }

    // Pull remote → local (only sessions that don't exist locally).
    // Fetch each missing session individually instead of all at once.
    final localSessionIds = {for (final s in localSessions) s.id};
    for (final remoteId in remoteSessionTs.keys) {
      if (!localSessionIds.contains(remoteId)) {
        final session =
            await remote.fetchSession(remoteId, includePoints: true);
        if (session != null) {
          await local.saveSessionRun(session);
          transferred++;
        }
      }
    }

    // --- Free rides ---
    final localFreeRides = await local.getAllFreeRides();
    final remoteFreeRideTs = await remote.fetchFreeRideTimestamps();

    // Push local → remote
    for (final ride in localFreeRides) {
      final remoteUpdated = remoteFreeRideTs[ride.id];
      if (SyncPlanner.shouldPush(
        localUpdatedAt: ride.endedAt,
        remoteUpdatedAt: remoteUpdated,
      )) {
        // Re-load with telemetry for push
        final full = await local.getFreeRideRun(ride.id);
        if (full != null) {
          await remote.upsertFreeRide(full);
          transferred++;
        }
      }
    }

    // Pull remote → local (only rides that don't exist locally)
    final localFreeRideIds = {for (final r in localFreeRides) r.id};
    for (final remoteId in remoteFreeRideTs.keys) {
      if (!localFreeRideIds.contains(remoteId)) {
        final ride = await remote.fetchFreeRide(remoteId, includePoints: true);
        if (ride != null) {
          await local.saveFreeRideRun(ride);
          transferred++;
        }
      }
    }

    // --- Speed sessions ---
    if (speedRepository != null && userId != null) {
      transferred += await speedRepository!.pushAllForUser(userId!);
      transferred += await speedRepository!.pullAllForUser(userId!);
    }

    return transferred;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _periodicTimer?.cancel();
    _autoSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _changesSubscription?.cancel();
    super.dispose();
  }
}

enum SyncStatus { idle, syncing, error, success, offline }
