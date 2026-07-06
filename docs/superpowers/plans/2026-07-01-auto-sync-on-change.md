# Auto-sync on change + status text (no button) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the drawer's "Sync now" button with a small status text, and make the app auto-sync ~1 minute after any local change (debounce resets on each change), keeping the 5-minute periodic download.

**Architecture:** `LocalDraftRepository.changes` (already emitted on every write) becomes the trigger. `SyncService` subscribes to it, sets a `hasPendingChanges` flag, and (re)arms a debounce `Timer` that calls the existing bidirectional `sync()`. Writes that happen *during* a sync are ignored (they are the sync's own pull/thumbnail writes), which also prevents a pull→re-sync loop. The drawer renders a pure `syncStatusDisplay(...)` → `(Color, String)`. To unit-test `SyncService` with a fake backend, its remote dependency is narrowed behind a new `SyncRemote` interface (mirroring the existing `OfficialRoutesRemote` pattern).

**Tech Stack:** Dart / Flutter, `sqflite` (local), Supabase (remote), `connectivity_plus`, `flutter_test` + `sqflite_common_ffi` for tests, Flutter `gen-l10n` for localization.

---

## File Structure

- **Create** `movile_app/lib/src/services/sync/sync_remote.dart` — narrow remote interface `SyncService` depends on.
- **Modify** `movile_app/lib/src/data/repositories/supabase_repository.dart` — `implements SyncRemote` + `@override` on the 12 methods it already defines.
- **Modify** `movile_app/lib/src/services/sync/sync_service.dart` — retype `remote` to `SyncRemote`; add `autoSyncDebounce`, injectable `connectivityStream`, `changes` subscription, `hasPendingChanges`, debounce timer, ignore-while-syncing guard, clear-on-success.
- **Create** `movile_app/lib/src/shared/widgets/sync_status_display.dart` — pure `(Color, String) syncStatusDisplay(...)`.
- **Modify** `movile_app/lib/src/shared/widgets/app_drawer.dart` — remove button, render status via `syncStatusDisplay`.
- **Modify** `movile_app/lib/l10n/app_es.arb`, `app_en.arb` (+ regenerated `app_localizations*.dart`) — add `drawerSyncPending`, remove `drawerSyncNow`.
- **Create** tests: `test/services/sync/sync_service_test.dart`, `test/shared/widgets/sync_status_display_test.dart`.

Reference facts (verified in the current code):
- `SupabaseRepository` is declared `class SupabaseRepository implements OfficialRoutesRemote {` at line 19; it already `@override`-annotates its `OfficialRoutesRemote` method.
- Lint set is `package:flutter_lints/flutter.yaml`, which enforces `annotate_overrides` → every interface method needs `@override`.
- `SyncService.remote` is declared `final SupabaseRepository remote;` at line 37; its constructor subscribes to connectivity at lines 32-33.
- The drawer's sync UI is `_SyncSection` (lines 308-417 of `app_drawer.dart`), rendered inside a `ListenableBuilder` over `syncService` (lines 194-198).
- l10n: template is `app_en.arb`; run `flutter gen-l10n` from `movile_app/` to regenerate. Generated files are committed.

---

### Task 1: Extract `SyncRemote` interface and decouple `SyncService`

Pure refactor, no behavior change. Verified by analyzer + existing tests.

**Files:**
- Create: `movile_app/lib/src/services/sync/sync_remote.dart`
- Modify: `movile_app/lib/src/data/repositories/supabase_repository.dart:19`
- Modify: `movile_app/lib/src/services/sync/sync_service.dart:37`

- [ ] **Step 1: Create the interface**

Create `movile_app/lib/src/services/sync/sync_remote.dart`:

```dart
import 'package:splitway_core/splitway_core.dart';

/// Narrow remote surface that [SyncService] depends on, mirroring the
/// [OfficialRoutesRemote] pattern so the service can be unit-tested against a
/// fake backend without a live Supabase client. [SupabaseRepository]
/// implements this in addition to [OfficialRoutesRemote].
abstract class SyncRemote {
  // Routes
  Future<Map<String, DateTime>> fetchRouteTimestamps();
  Future<List<RouteTemplate>> fetchAllRoutes();
  Future<RouteTemplate> upsertRoute(RouteTemplate route);
  Future<void> deleteRoute(String id);

  // Sessions
  Future<Map<String, DateTime>> fetchSessionTimestamps();
  Future<SessionRun?> fetchSession(String id, {bool includePoints = false});
  Future<void> upsertSession(SessionRun session);
  Future<void> deleteSession(String id);

  // Free rides
  Future<Map<String, DateTime>> fetchFreeRideTimestamps();
  Future<FreeRideRun?> fetchFreeRide(String id, {bool includePoints = false});
  Future<void> upsertFreeRide(FreeRideRun ride);
  Future<void> deleteFreeRide(String id);
}
```

- [ ] **Step 2: Make `SupabaseRepository` implement it**

In `supabase_repository.dart`, add the import near the other project imports (after line 8, `import '../services/official_routes/official_routes_service.dart';` — keep alphabetical-ish grouping):

```dart
import '../../services/sync/sync_remote.dart';
```

Change the class declaration (line 19) from:

```dart
class SupabaseRepository implements OfficialRoutesRemote {
```

to:

```dart
class SupabaseRepository implements OfficialRoutesRemote, SyncRemote {
```

Then add `@override` on the line immediately above each of these 12 method declarations (they already exist; only the annotation is added):
- `Future<RouteTemplate> upsertRoute(RouteTemplate route)` (~line 33)
- `Future<List<RouteTemplate>> fetchAllRoutes()` (~line 85)
- `Future<void> deleteRoute(String id)` (~line 139)
- `Future<void> upsertSession(SessionRun session)` (~line 157)
- `Future<SessionRun?> fetchSession(` (~line 220)
- `Future<void> deleteSession(String id)` (~line 245)
- `Future<void> upsertFreeRide(FreeRideRun ride)` (~line 253)
- `Future<void> deleteFreeRide(String id)` (~line 285)
- `Future<FreeRideRun?> fetchFreeRide(` (~line 303)
- `Future<Map<String, DateTime>> fetchFreeRideTimestamps()` (~line 328)
- `Future<Map<String, DateTime>> fetchRouteTimestamps()` (~line 343)
- `Future<Map<String, DateTime>> fetchSessionTimestamps()` (~line 355)

- [ ] **Step 3: Retype `SyncService.remote`**

In `sync_service.dart`, add the import (near the other repository imports, after line 9 `import '../../data/repositories/supabase_repository.dart';`):

```dart
import 'sync_remote.dart';
```

Change line 37 from:

```dart
  final SupabaseRepository remote;
```

to:

```dart
  final SyncRemote remote;
```

Leave the `SupabaseRepository` import in place only if still used; if the analyzer reports it as unused after this change, remove `import '../../data/repositories/supabase_repository.dart';`.

- [ ] **Step 4: Analyze + run existing tests**

Run: `cd movile_app && flutter analyze`
Expected: `No issues found!` (the `annotate_overrides` lint is satisfied by Step 2).

Run: `cd movile_app && flutter test`
Expected: all existing tests pass (no behavior changed; `app.dart` still passes a concrete `SupabaseRepository`, which now satisfies `SyncRemote`).

- [ ] **Step 5: Commit**

```bash
git add movile_app/lib/src/services/sync/sync_remote.dart movile_app/lib/src/data/repositories/supabase_repository.dart movile_app/lib/src/services/sync/sync_service.dart
git commit -m "refactor(sync): depend on narrow SyncRemote interface"
```

---

### Task 2: Add `drawerSyncPending` localization

Add the new key first so later tasks can reference it. Do **not** remove `drawerSyncNow` yet (the drawer still uses it until Task 5).

**Files:**
- Modify: `movile_app/lib/l10n/app_es.arb:41`
- Modify: `movile_app/lib/l10n/app_en.arb` (mirror location)

- [ ] **Step 1: Add the Spanish string**

In `app_es.arb`, add after the `drawerSyncOffline` line (line 40):

```json
  "drawerSyncPending": "CAMBIOS PENDIENTES",
```

- [ ] **Step 2: Add the English string**

In `app_en.arb`, add after its `drawerSyncOffline` line:

```json
  "drawerSyncPending": "PENDING CHANGES",
```

- [ ] **Step 3: Regenerate localizations**

Run: `cd movile_app && flutter gen-l10n`
Expected: exits 0; `lib/l10n/app_localizations.dart` now declares `String get drawerSyncPending;` and both `app_localizations_es.dart` / `app_localizations_en.dart` implement it.

- [ ] **Step 4: Commit**

```bash
git add movile_app/lib/l10n/
git commit -m "i18n: add drawerSyncPending string"
```

---

### Task 3: Pure `syncStatusDisplay` function (TDD)

**Files:**
- Test: `movile_app/test/shared/widgets/sync_status_display_test.dart`
- Create: `movile_app/lib/src/shared/widgets/sync_status_display.dart`

- [ ] **Step 1: Write the failing test**

Create `movile_app/test/shared/widgets/sync_status_display_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitway_mobile/l10n/app_localizations_en.dart';
import 'package:splitway_mobile/src/services/sync/sync_service.dart';
import 'package:splitway_mobile/src/shared/widgets/sync_status_display.dart';

void main() {
  final l = AppLocalizationsEn();
  const amber = Color(0xFFFFB300);
  const green = Color(0xFF4CAF50);
  const blue = Color(0xFF42A5F5);
  const red = Color(0xFFEF5350);
  const orange = Color(0xFFFF9800);

  test('offline shows offline label', () {
    final (color, label) = syncStatusDisplay(
        SyncStatus.offline, false, null, l);
    expect(color, orange);
    expect(label, l.drawerSyncOffline);
  });

  test('syncing shows syncing label', () {
    final (color, label) = syncStatusDisplay(
        SyncStatus.syncing, false, null, l);
    expect(color, blue);
    expect(label, l.drawerSyncSyncing);
  });

  test('error shows error label', () {
    final (color, label) = syncStatusDisplay(
        SyncStatus.error, false, null, l);
    expect(color, red);
    expect(label, l.drawerSyncError);
  });

  test('idle with pending changes shows pending label', () {
    final (color, label) = syncStatusDisplay(
        SyncStatus.idle, true, DateTime(2026, 1, 1), l);
    expect(color, amber);
    expect(label, l.drawerSyncPending);
  });

  test('success with pending changes still shows pending', () {
    final (color, label) = syncStatusDisplay(
        SyncStatus.success, true, DateTime(2026, 1, 1), l);
    expect(color, amber);
    expect(label, l.drawerSyncPending);
  });

  test('idle, not pending, never synced shows synced', () {
    final (color, label) = syncStatusDisplay(
        SyncStatus.idle, false, null, l);
    expect(color, green);
    expect(label, l.drawerSyncSynced);
  });

  test('idle, not pending, synced 2 min ago shows minutes', () {
    final now = DateTime(2026, 1, 1, 12, 0);
    final last = DateTime(2026, 1, 1, 11, 58);
    final (color, label) = syncStatusDisplay(
        SyncStatus.idle, false, last, l, now: now);
    expect(color, green);
    expect(label, l.drawerSyncSyncedMinutes(2));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd movile_app && flutter test test/shared/widgets/sync_status_display_test.dart`
Expected: FAIL — `sync_status_display.dart` / `syncStatusDisplay` do not exist (compile error).

- [ ] **Step 3: Write the implementation**

Create `movile_app/lib/src/shared/widgets/sync_status_display.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../../services/sync/sync_service.dart';

/// Pure mapping from sync state to the drawer's status dot color + label.
/// Kept free of any [SyncService] dependency so it can be unit-tested with
/// direct values. [now] is injectable for deterministic "synced N min ago"
/// tests; it defaults to [DateTime.now].
(Color, String) syncStatusDisplay(
  SyncStatus status,
  bool hasPendingChanges,
  DateTime? lastSyncedAt,
  AppLocalizations l, {
  DateTime? now,
}) {
  const green = Color(0xFF4CAF50);
  const blue = Color(0xFF42A5F5);
  const red = Color(0xFFEF5350);
  const orange = Color(0xFFFF9800);
  const amber = Color(0xFFFFB300);

  switch (status) {
    case SyncStatus.offline:
      return (orange, l.drawerSyncOffline);
    case SyncStatus.syncing:
      return (blue, l.drawerSyncSyncing);
    case SyncStatus.error:
      return (red, l.drawerSyncError);
    case SyncStatus.idle:
    case SyncStatus.success:
      if (hasPendingChanges) {
        return (amber, l.drawerSyncPending);
      }
      return (green, _idleLabel(l, lastSyncedAt, now ?? DateTime.now()));
  }
}

String _idleLabel(AppLocalizations l, DateTime? last, DateTime now) {
  if (last == null) return l.drawerSyncSynced;
  final diff = now.difference(last);
  if (diff.inMinutes < 1) return l.drawerSyncSyncedNow;
  if (diff.inMinutes < 60) return l.drawerSyncSyncedMinutes(diff.inMinutes);
  final time = '${last.hour}:${last.minute.toString().padLeft(2, '0')}';
  return l.drawerSyncSyncedAt(time);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd movile_app && flutter test test/shared/widgets/sync_status_display_test.dart`
Expected: PASS (all 7 tests).

- [ ] **Step 5: Commit**

```bash
git add movile_app/lib/src/shared/widgets/sync_status_display.dart movile_app/test/shared/widgets/sync_status_display_test.dart
git commit -m "feat(sync): pure syncStatusDisplay mapping with pending state"
```

---

### Task 4: `SyncService` change-triggered debounced auto-sync (TDD)

**Files:**
- Test: `movile_app/test/services/sync/sync_service_test.dart`
- Modify: `movile_app/lib/src/services/sync/sync_service.dart`

- [ ] **Step 1: Write the failing test**

Create `movile_app/test/services/sync/sync_service_test.dart`:

```dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitway_core/splitway_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:splitway_mobile/src/data/local/splitway_local_database.dart';
import 'package:splitway_mobile/src/data/repositories/local_draft_repository.dart';
import 'package:splitway_mobile/src/services/sync/sync_remote.dart';
import 'package:splitway_mobile/src/services/sync/sync_service.dart';

/// Fake backend: an empty local DB makes [SyncService._doSync] call only the
/// four fetch methods below, so a fresh install syncs without any upserts.
/// [fetchRouteTimestamps] doubles as a "a sync pass ran" counter and an
/// optional gate to hold a sync in flight. Everything else routes through
/// noSuchMethod (never reached in these tests).
class _FakeSyncRemote implements SyncRemote {
  int passes = 0;
  Completer<void>? gate;

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

  test('changes emitted while a sync is in flight are ignored', () async {
    remote.gate = Completer<void>();

    local.userId = 'u1'; // triggers debounce
    // Wait until the sync is in flight (status == syncing, blocked on gate).
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(sync.status, SyncStatus.syncing);

    // A change now (as a real pull/thumbnail write would appear) must not set
    // pending nor schedule another sync.
    local.userId = 'u2';
    await Future<void>.delayed(Duration.zero);
    expect(sync.hasPendingChanges, isFalse);

    remote.gate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(remote.passes, 1); // no second pass was scheduled
    expect(sync.hasPendingChanges, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd movile_app && flutter test test/services/sync/sync_service_test.dart`
Expected: FAIL — `SyncService` has no `autoSyncDebounce`/`connectivityStream` params and no `hasPendingChanges` getter (compile error).

- [ ] **Step 3: Implement the changes in `sync_service.dart`**

Add `connectivity_plus` is already imported. Update the constructor and fields.

Replace the constructor + connectivity subscription (current lines 25-34):

```dart
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
```

Add `autoSyncDebounce` to the final fields (after `syncInterval` at line 40):

```dart
  final Duration autoSyncDebounce;
```

Add the new private fields (near line 42, alongside `_periodicTimer`):

```dart
  Timer? _autoSyncTimer;
  StreamSubscription<void>? _changesSubscription;
```

Add the pending-changes state (near `_status` at lines 47-48):

```dart
  bool _hasPendingChanges = false;
  bool get hasPendingChanges => _hasPendingChanges;
```

Add the change handler (place it just above `_onConnectivityChanged`, ~line 123):

```dart
  /// Reacts to a local write. Writes that occur *while a sync is running* are
  /// the sync's own pull/thumbnail writes (they flow through the same
  /// [LocalDraftRepository.changes] stream), so they are ignored — this both
  /// avoids marking a false "pending" state and prevents a pull→re-sync loop.
  /// Any other write flags pending and (re)arms the debounce; the timer resets
  /// on each change so a burst of edits is uploaded together.
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
```

In `sync()`, clear the pending flag on success. Change the success branch (current lines 155-159) from:

```dart
      final transferred = await _doSync();
      _status = SyncStatus.success;
      _lastSyncedAt = DateTime.now();
      notifyListeners();
      return transferred;
```

to:

```dart
      final transferred = await _doSync();
      _status = SyncStatus.success;
      _lastSyncedAt = DateTime.now();
      _hasPendingChanges = false;
      notifyListeners();
      return transferred;
```

Update `dispose()` (current lines 380-386) to cancel the new timer + subscription:

```dart
  @override
  void dispose() {
    _disposed = true;
    _periodicTimer?.cancel();
    _autoSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _changesSubscription?.cancel();
    super.dispose();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd movile_app && flutter test test/services/sync/sync_service_test.dart`
Expected: PASS (all 3 tests).

- [ ] **Step 5: Analyze**

Run: `cd movile_app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add movile_app/lib/src/services/sync/sync_service.dart movile_app/test/services/sync/sync_service_test.dart
git commit -m "feat(sync): auto-sync 1 min after local changes (debounced) + pending flag"
```

---

### Task 5: Drawer — remove button, render status text

**Files:**
- Modify: `movile_app/lib/src/shared/widgets/app_drawer.dart:308-417`

- [ ] **Step 1: Import the pure helper**

At the top of `app_drawer.dart`, add after the existing imports (after line 7 `import '../../services/sync/sync_service.dart';`):

```dart
import 'sync_status_display.dart';
```

- [ ] **Step 2: Replace the `_SyncSection` widget body**

Replace the entire `_SyncSection` class (lines 308-417) with:

```dart
class _SyncSection extends StatelessWidget {
  const _SyncSection({required this.syncService});

  final SyncService syncService;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (dotColor, label) = syncStatusDisplay(
      syncService.status,
      syncService.hasPendingChanges,
      syncService.lastSyncedAt,
      l,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
```

This removes the gradient button and the now-unused `_idleLabel` method (its logic now lives in `sync_status_display.dart`). The section remains wrapped in the existing `ListenableBuilder` (lines 194-198), so the text updates live when `status` or `hasPendingChanges` change.

- [ ] **Step 3: Analyze**

Run: `cd movile_app && flutter analyze`
Expected: `No issues found!` (no remaining references to `syncService.sync()` from the button, no unused `_idleLabel`).

- [ ] **Step 4: Run the full test suite**

Run: `cd movile_app && flutter test`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add movile_app/lib/src/shared/widgets/app_drawer.dart
git commit -m "feat(sync): replace drawer sync button with live status text"
```

---

### Task 6: Remove the now-unused `drawerSyncNow` string

The button is gone, so `drawerSyncNow` is dead.

**Files:**
- Modify: `movile_app/lib/l10n/app_es.arb:41`
- Modify: `movile_app/lib/l10n/app_en.arb`

- [ ] **Step 1: Delete the key from both ARB files**

Remove the `"drawerSyncNow": ...,` line from `app_es.arb` and from `app_en.arb`.

- [ ] **Step 2: Regenerate**

Run: `cd movile_app && flutter gen-l10n`
Expected: exits 0; `drawerSyncNow` getter no longer generated.

- [ ] **Step 3: Verify nothing references it**

Run: `cd movile_app && grep -rn "drawerSyncNow" lib test`
Expected: no output (empty).

- [ ] **Step 4: Analyze**

Run: `cd movile_app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add movile_app/lib/l10n/
git commit -m "i18n: drop unused drawerSyncNow string"
```

---

### Task 7: Full verification

- [ ] **Step 1: Analyze + full test suite**

Run: `cd movile_app && flutter analyze && flutter test`
Expected: `No issues found!` and all tests pass.

- [ ] **Step 2: Manual run (recommended)**

Launch the app (signed in), open the drawer. Confirm:
- No "Sync now" button; only the dot + status text.
- Make a local change (create/edit a route, or finish a ride). The text switches to **CAMBIOS PENDIENTES** (amber dot).
- Within ~1 minute (or sooner if another change resets it), it flips to **SINCRONIZANDO…** then **SINCRONIZADO** (green).
- Toggling connectivity off shows **SIN CONEXIÓN**.

For a faster manual loop, you may temporarily construct the app's `SyncService` with a short `autoSyncDebounce` in `app.dart:_createSyncService`, but **revert** any such change before the final commit.

- [ ] **Step 3: Final confirmation**

No extra commit needed if Tasks 1-6 are already committed and the tree is clean (`git status`).

---

## Notes / Out of scope

- `hasPendingChanges` is in-memory only; on cold start the initial `sync()` (from `startPeriodicSync`) uploads any locally-pending data via last-write-wins, so persistence is unnecessary.
- The 5-minute periodic download (`startPeriodicSync`) and connectivity-triggered sync are unchanged; they also act as a safety net for the rare case where a user write lands during an in-flight sync (which `_onLocalChange` intentionally ignores).
- `_doSync` / last-write-wins logic is untouched.
