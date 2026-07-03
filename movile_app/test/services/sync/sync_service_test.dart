import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitway_core/splitway_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:splitway_mobile/src/data/local/splitway_local_database.dart';
import 'package:splitway_mobile/src/data/repositories/local_draft_repository.dart';
import 'package:splitway_mobile/src/services/sync/sync_remote.dart';
import 'package:splitway_mobile/src/services/sync/sync_service.dart';

/// Fake backend: an empty local DB makes [SyncService]'s internal sync call
/// only the four fetch methods below, so a fresh install syncs without any
/// upserts. [fetchRouteTimestamps] doubles as a "a sync pass ran" counter and
/// an optional gate to hold a sync in flight. Everything else routes through
/// noSuchMethod (never reached in these tests).
class _FakeSyncRemote implements SyncRemote {
  int passes = 0;
  Completer<void>? gate;
  @override
  bool hasSession = true;

  @override
  Future<Map<String, DateTime>> fetchRouteTimestamps() async {
    passes++;
    if (gate != null) await gate!.future;
    return {};
  }

  @override
  Future<List<RouteTemplate>> fetchAllRoutes() async => const [];

  @override
  Future<Map<String, DateTime>> fetchSessionTimestamps() async => {};

  @override
  Future<Map<String, DateTime>> fetchFreeRideTimestamps() async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late SplitwayLocalDatabase db;
  late LocalDraftRepository local;
  late StreamController<List<ConnectivityResult>> connectivity;
  late _FakeSyncRemote remote;
  late SyncService sync;

  setUp(() async {
    db = await SplitwayLocalDatabase.open(overridePath: inMemoryDatabasePath);
    local = LocalDraftRepository(db);
    connectivity = StreamController<List<ConnectivityResult>>.broadcast();
    remote = _FakeSyncRemote();
    sync = SyncService(
      local: local,
      remote: remote,
      autoSyncDebounce: const Duration(milliseconds: 30),
      connectivityStream: connectivity.stream,
    );
    // NOTE: startPeriodicSync() is intentionally NOT called, so the only sync
    // that runs is the change-triggered debounced one.
  });

  tearDown(() async {
    sync.dispose();
    await connectivity.close();
    await local.dispose();
    await db.close();
  });

  test('a local change marks pending and syncs once after the debounce',
      () async {
    local.userId = 'u1'; // fires repo.changes
    await Future<void>.delayed(Duration.zero); // let the event dispatch
    expect(sync.hasPendingChanges, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remote.passes, 1);
    expect(sync.hasPendingChanges, isFalse);
  });

  test('rapid successive changes collapse into a single sync', () async {
    local.userId = 'u1';
    await Future<void>.delayed(const Duration(milliseconds: 10));
    local.userId = 'u2'; // resets the debounce
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remote.passes, 1);
  });

  test('does not sync while there is no authenticated session', () async {
    // A lost session (e.g. a stale refresh token forced a signOut) would make
    // requests go out as anon and RPCs reject them with a 42501. The guard must
    // skip the sync entirely and keep the changes pending for a later retry.
    remote.hasSession = false;

    local.userId = 'u1'; // fires a change → arms the debounce
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(remote.passes, 0);
    expect(sync.hasPendingChanges, isTrue);
  });

  test('changes emitted while a sync is in flight are ignored', () async {
    remote.gate = Completer<void>();

    local.userId = 'u1'; // triggers debounce
    // Wait until the sync is in flight (status == syncing, blocked on gate).
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(sync.status, SyncStatus.syncing);

    // A change now (as a real pull/thumbnail write would appear) must be
    // ignored by the guard, so it does NOT schedule a second sync.
    local.userId = 'u2';
    await Future<void>.delayed(Duration.zero);

    remote.gate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remote.passes, 1); // guard prevented a second sync pass
    expect(sync.hasPendingChanges, isFalse); // cleared on success
  });
}
