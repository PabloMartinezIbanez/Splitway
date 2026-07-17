# Speed Test — Auto-Launch Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an "Auto" option to the speed-test countdown that skips the countdown and starts the session automatically when the vehicle accelerates.

**Architecture:** Encode "auto" as `countdownSeconds == 0`. Add a `motionDetected` `ValueNotifier<bool>` to `SpeedMeasurementService` set from the existing sustained-motion detector. Add a `waitingForLaunch` phase to `SpeedSessionController`; when in that phase, skip beeps/false-start and transition to `running` on `motionDetected == true`. Add a fourth chip in the setup UI and a new `WaitingForLaunchOverlay` on the session screen. Compensate for `service.elapsed` accumulating during the wait via a `displayedElapsed` getter on the controller.

**Tech Stack:** Flutter (Dart), `ValueNotifier`, ARB-based `flutter gen-l10n`, `flutter_test`.

## Global Constraints

- Language convention: existing chips localize numbers via `speedSetupSecondsValue`; add a distinct string key for `Auto` — do not overload the plural.
- Persisted schema: `SpeedSession.countdownSeconds` remains `int`; do not change the DAO schema.
- Existing countdown flow (3/5/10 s) must remain byte-for-byte identical in behaviour (regression protected by a controller test).
- Existing test seams (`SpeedMeasurementService.forTesting` + `debugInjectSample`) must be used for service tests — do not stub `Geolocator` / `sensors_plus`.
- Spec of reference: `movile_app/docs/superpowers/specs/2026-07-17-speed-test-auto-launch-design.md`.

---

## File Structure

**Create:**
- `movile_app/lib/src/features/speed/widgets/waiting_for_launch_overlay.dart` — the new overlay widget.
- `movile_app/test/features/speed/speed_session_controller_test.dart` — controller behaviour tests (didn't exist before).

**Modify:**
- `movile_app/lib/src/services/speed/speed_measurement_service.dart` — add `motionDetected` notifier + set/reset points.
- `movile_app/lib/src/features/speed/speed_session_controller.dart` — new phase, auto-flow, `cancelWaiting`, `displayedElapsed`.
- `movile_app/lib/src/features/speed/speed_setup_screen.dart` — add `0` chip labeled "Auto".
- `movile_app/lib/src/features/speed/speed_session_screen.dart` — render the overlay in the `Stack`, use `displayedElapsed`.
- `movile_app/lib/l10n/app_en.arb`, `movile_app/lib/l10n/app_es.arb` — new keys.
- `movile_app/test/services/speed/speed_measurement_service_test.dart` — extend with `motionDetected` cases.
- `movile_app/test/features/speed/speed_setup_screen_test.dart` — assert the Auto chip flow.

---

## Task 1: `motionDetected` notifier on `SpeedMeasurementService`

**Files:**
- Modify: `movile_app/lib/src/services/speed/speed_measurement_service.dart`
- Test: `movile_app/test/services/speed/speed_measurement_service_test.dart`

**Interfaces produced:**
- `ValueNotifier<bool> motionDetected` (public field on `SpeedMeasurementService`), initialized to `false`.
- Set to `true` inside `_detectMilestones` at the exact moment `_motionStartTime` is fixed.
- Reset to `false` inside `start()`.

- [ ] **Step 1: Write the failing test for `motionDetected == true` when motion is sustained**

Append to `movile_app/test/services/speed/speed_measurement_service_test.dart` in a new group:

```dart
  group('SpeedMeasurementService motionDetected', () {
    test('flips to true once motion is sustained past the reaction window',
        () {
      final svc = SpeedMeasurementService.forTesting(
        targets: {SpeedMetric.zeroTo100},
      );
      svc.start();
      expect(svc.motionDetected.value, isFalse,
          reason: 'initial state after start() is not moving');

      // Sample below threshold — must not flip the flag.
      svc.debugInjectSample(const SpeedSample(
        tSinceStart: Duration(milliseconds: 100),
        speedKmh: 0.1,
        distanceM: 0,
        accelMs2: 0.1,
      ));
      expect(svc.motionDetected.value, isFalse,
          reason: 'sub-threshold sample must not trigger detection');

      // First above-threshold sample: anchors the candidate but sustain
      // (100 ms) hasn't elapsed yet.
      svc.debugInjectSample(const SpeedSample(
        tSinceStart: Duration(milliseconds: 200),
        speedKmh: 1.0,
        distanceM: 0.1,
        accelMs2: 2.0,
      ));
      expect(svc.motionDetected.value, isFalse,
          reason: 'sustain window not yet met');

      // Second above-threshold sample >= 100 ms later: motion confirmed.
      svc.debugInjectSample(const SpeedSample(
        tSinceStart: Duration(milliseconds: 350),
        speedKmh: 3.0,
        distanceM: 0.5,
        accelMs2: 2.5,
      ));
      expect(svc.motionDetected.value, isTrue,
          reason: 'sustained motion above threshold must set the flag');
    });

    test('start() resets motionDetected to false', () {
      final svc = SpeedMeasurementService.forTesting(
        targets: {SpeedMetric.zeroTo100},
      );
      svc.start();
      svc.debugInjectSample(const SpeedSample(
        tSinceStart: Duration(milliseconds: 200),
        speedKmh: 1.0,
        distanceM: 0.1,
        accelMs2: 2.0,
      ));
      svc.debugInjectSample(const SpeedSample(
        tSinceStart: Duration(milliseconds: 350),
        speedKmh: 3.0,
        distanceM: 0.5,
        accelMs2: 2.5,
      ));
      expect(svc.motionDetected.value, isTrue);

      svc.start();
      expect(svc.motionDetected.value, isFalse,
          reason: 'start() must reset detection state for retry');
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```powershell
cd movile_app
flutter test test/services/speed/speed_measurement_service_test.dart
```
Expected: the two new tests fail because `motionDetected` doesn't exist.

- [ ] **Step 3: Add the notifier field and disposal**

In `movile_app/lib/src/services/speed/speed_measurement_service.dart`, in the group of public `ValueNotifier`s (right after `elapsed`):

```dart
  final ValueNotifier<bool> motionDetected = ValueNotifier(false);
```

In `_closeNotifiers()`, add:
```dart
    motionDetected.dispose();
```
placed right after `elapsed.dispose();`.

- [ ] **Step 4: Set `motionDetected.value = true` when motion is confirmed**

In `_detectMilestones`, inside the block that fixes `_motionStartTime` (after `_motionStartTime = _reactionCandidateTime;`), add:

```dart
          motionDetected.value = true;
```

Placed **before** the `if (targets.contains(SpeedMetric.reactionTime))` line so that detection is reported even when reaction time is not a selected metric.

- [ ] **Step 5: Reset `motionDetected` in `start()`**

In `start()`, right after `_motionStartTime = null;`, add:

```dart
    motionDetected.value = false;
```

- [ ] **Step 6: Run the new tests to verify they pass**

Run:
```powershell
cd movile_app
flutter test test/services/speed/speed_measurement_service_test.dart
```
Expected: all tests in the file pass (existing plus the two new ones).

- [ ] **Step 7: Commit**

```bash
git add movile_app/lib/src/services/speed/speed_measurement_service.dart movile_app/test/services/speed/speed_measurement_service_test.dart
git commit -m "feat(speed): expose motionDetected notifier on SpeedMeasurementService"
```

---

## Task 2: `waitingForLaunch` phase + auto-flow in `SpeedSessionController`

**Files:**
- Modify: `movile_app/lib/src/features/speed/speed_session_controller.dart`
- Create: `movile_app/test/features/speed/speed_session_controller_test.dart`

**Interfaces consumed:**
- `SpeedMeasurementService.motionDetected: ValueNotifier<bool>` (Task 1).

**Interfaces produced:**
- Enum value `SpeedScreenPhase.waitingForLaunch`.
- `Duration get displayedElapsed` on `SpeedSessionController`.
- `Future<void> cancelWaiting()` on `SpeedSessionController`.
- Contract: when `countdownSeconds == 0`, `begin()` transitions `ready → waitingForLaunch → running` without going through `arming` or `countdown`, and never mutates `countdownValue`.

- [ ] **Step 1: Write failing test — begin() skips countdown when `countdownSeconds == 0`**

Create `movile_app/test/features/speed/speed_session_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:splitway_mobile/src/data/repositories/speed_repository.dart';
import 'package:splitway_mobile/src/features/speed/speed_session_controller.dart';
import 'package:splitway_mobile/src/services/speed/speed_metric.dart';
import 'package:splitway_mobile/src/services/speed/speed_sample.dart';
import 'package:splitway_mobile/src/services/speed/speed_session.dart';

class _FakeSpeedRepository implements SpeedRepository {
  final List<SpeedSession> saved = [];
  @override
  Future<void> save(SpeedSession session) async => saved.add(session);
  @override
  Future<List<SpeedSession>> listAll() async => List.of(saved);
  @override
  Future<SpeedSession?> getById(String id) async =>
      saved.where((s) => s.id == id).cast<SpeedSession?>().firstOrNull;
  @override
  Future<void> delete(String id) async =>
      saved.removeWhere((s) => s.id == id);
  @override
  Future<void> updateName(String id, String name) async {}
}

SpeedSessionController _makeController({required int countdownSeconds}) {
  return SpeedSessionController(
    userId: null,
    vehicleId: null,
    vehicleName: 'Test Car',
    metrics: const {SpeedMetric.zeroTo100},
    countdownSeconds: countdownSeconds,
    userProvidedName: null,
    repository: _FakeSpeedRepository(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeedSessionController auto-launch mode', () {
    test('begin() with countdownSeconds==0 goes ready → waitingForLaunch',
        () async {
      final c = _makeController(countdownSeconds: 0);
      expect(c.phase, SpeedScreenPhase.ready);
      await c.begin();
      expect(c.phase, SpeedScreenPhase.waitingForLaunch,
          reason: 'auto mode must skip arming/countdown');
      expect(c.countdownValue, 0,
          reason: 'countdownValue must not be mutated in auto mode');
      c.dispose();
    });

    test('transitions to running when motion is detected', () async {
      final c = _makeController(countdownSeconds: 0);
      await c.begin();
      expect(c.phase, SpeedScreenPhase.waitingForLaunch);

      // Drive the service into confirmed-motion state.
      c.service.debugInjectSample(const SpeedSample(
        tSinceStart: Duration(milliseconds: 200),
        speedKmh: 1.0,
        distanceM: 0.1,
        accelMs2: 2.0,
      ));
      c.service.debugInjectSample(const SpeedSample(
        tSinceStart: Duration(milliseconds: 350),
        speedKmh: 3.0,
        distanceM: 0.5,
        accelMs2: 2.5,
      ));

      // Let the listener fire.
      await Future<void>.delayed(Duration.zero);
      expect(c.phase, SpeedScreenPhase.running,
          reason: 'motionDetected must move the controller to running');
      expect(c.startedAt, isNotNull);
      c.dispose();
    });

    test('cancelWaiting() returns to ready without emitting running',
        () async {
      final c = _makeController(countdownSeconds: 0);
      await c.begin();
      expect(c.phase, SpeedScreenPhase.waitingForLaunch);

      await c.cancelWaiting();
      expect(c.phase, SpeedScreenPhase.ready);
      expect(c.startedAt, isNull);
      c.dispose();
    });
  });

  group('SpeedSessionController countdown mode regression', () {
    test('begin() with countdownSeconds>0 arms and enters countdown',
        () async {
      final c = _makeController(countdownSeconds: 3);
      await c.begin();
      // After _arm(), phase is countdown and countdownValue is seeded.
      expect(c.phase, SpeedScreenPhase.countdown);
      expect(c.countdownValue, 3);
      c.dispose();
    });
  });
}
```

**Note:** `SpeedSessionController` — you may need to add a test seam for the `BeepPlayer` (see Task 2 Step 5). If the tests currently touch real audio on start, guard `beep.preload()` and `beep.tick/go/falseStart` behind an optional injected player defaulting to `BeepPlayer()`.

- [ ] **Step 2: Register the necessary test seam for BeepPlayer**

In `movile_app/lib/src/features/speed/speed_session_controller.dart`, change the constructor to accept an optional `BeepPlayer` so tests avoid loading audio assets:

```dart
  SpeedSessionController({
    required this.userId,
    required this.vehicleId,
    required this.vehicleName,
    required this.metrics,
    required this.countdownSeconds,
    required this.userProvidedName,
    required this.repository,
    BeepPlayer? beep,
  })  : service = SpeedMeasurementService(targets: metrics),
        beep = beep ?? BeepPlayer();
```

Leave the field declaration `final BeepPlayer beep;` as-is (the initializer covers it).

- [ ] **Step 3: Add the `waitingForLaunch` enum value**

At the top of `speed_session_controller.dart`, extend the enum:

```dart
enum SpeedScreenPhase {
  ready,
  arming,
  countdown,
  waitingForLaunch,
  running,
  falseStart,
  finished,
}
```

- [ ] **Step 4: Branch `begin()` on `countdownSeconds == 0` and add helpers**

Replace the current `begin()` body with:

```dart
  Future<void> begin() async {
    await beep.preload();
    _falseStartSub = service.falseStartStream.listen((_) {
      _onFalseStart();
    });
    if (countdownSeconds == 0) {
      await _waitForLaunch();
    } else {
      await _arm();
    }
  }
```

Add these new fields under the existing state fields, next to `_countdownTimers`:

```dart
  Duration _launchElapsedOffset = Duration.zero;
  bool _motionListenerAttached = false;
```

Add the new private method `_waitForLaunch` right after `_arm()`:

```dart
  Future<void> _waitForLaunch() async {
    phase = SpeedScreenPhase.waitingForLaunch;
    countdownValue = 0;
    _launchElapsedOffset = Duration.zero;
    notifyListeners();
    await service.liveStart();
    if (_disposed) return;
    if (!_motionListenerAttached) {
      service.motionDetected.addListener(_onMotionDetected);
      _motionListenerAttached = true;
    }
    if (!_resultsListenerAttached) {
      service.results.addListener(_maybeFinish);
      _resultsListenerAttached = true;
    }
  }

  void _onMotionDetected() {
    if (_disposed) return;
    if (!service.motionDetected.value) return;
    if (phase != SpeedScreenPhase.waitingForLaunch) return;
    _launchElapsedOffset = service.elapsed.value;
    startedAt = DateTime.now();
    phase = SpeedScreenPhase.running;
    notifyListeners();
  }

  Future<void> cancelWaiting() async {
    if (phase != SpeedScreenPhase.waitingForLaunch) return;
    await service.liveStop();
    phase = SpeedScreenPhase.ready;
    startedAt = null;
    notifyListeners();
  }
```

- [ ] **Step 5: Expose `displayedElapsed` getter**

Add this getter on `SpeedSessionController`, next to the other public fields:

```dart
  Duration get displayedElapsed {
    if (phase == SpeedScreenPhase.waitingForLaunch) return Duration.zero;
    final raw = service.elapsed.value;
    final offset = _launchElapsedOffset;
    if (raw <= offset) return Duration.zero;
    return raw - offset;
  }
```

- [ ] **Step 6: Handle retry() and dispose() for the auto path**

In `retry()`, branch on `countdownSeconds`:

```dart
  Future<void> retry() async {
    if (countdownSeconds == 0) {
      _launchElapsedOffset = Duration.zero;
      startedAt = null;
      finishedAt = null;
      await _waitForLaunch();
    } else {
      await _arm();
    }
  }
```

In `dispose()`, detach the motion listener (before the existing `unawaited(service.disposeAsync())` line):

```dart
    if (_motionListenerAttached) {
      service.motionDetected.removeListener(_onMotionDetected);
    }
```

- [ ] **Step 7: Run controller tests to verify they pass**

Run:
```powershell
cd movile_app
flutter test test/features/speed/speed_session_controller_test.dart
```
Expected: all four tests pass.

- [ ] **Step 8: Run the whole speed test suite to verify no regression**

Run:
```powershell
cd movile_app
flutter test test/services/speed test/features/speed
```
Expected: everything passes.

- [ ] **Step 9: Commit**

```bash
git add movile_app/lib/src/features/speed/speed_session_controller.dart movile_app/test/features/speed/speed_session_controller_test.dart
git commit -m "feat(speed): add waitingForLaunch phase and auto-launch flow to SpeedSessionController"
```

---

## Task 3: L10n keys

**Files:**
- Modify: `movile_app/lib/l10n/app_en.arb`
- Modify: `movile_app/lib/l10n/app_es.arb`

**Interfaces produced:** four new getters on `AppLocalizations`:
- `speedSetupCountdownAuto` (`Auto` / `Auto`)
- `speedWaitingForLaunchTitle` (`Waiting for launch…` / `Esperando arranque…`)
- `speedWaitingForLaunchSubtitle` (`Timing will start when the vehicle accelerates` / `El cronómetro empezará cuando el coche acelere`)
- `speedWaitingForLaunchCancel` (`Cancel` / `Cancelar`)

- [ ] **Step 1: Add the keys to `app_es.arb`**

Insert these four lines in `movile_app/lib/l10n/app_es.arb` right after the existing `"speedSetupSecondsValue"` block (line ~562), preserving JSON commas:

```json
  "speedSetupCountdownAuto": "Auto",
  "speedWaitingForLaunchTitle": "Esperando arranque…",
  "speedWaitingForLaunchSubtitle": "El cronómetro empezará cuando el coche acelere",
  "speedWaitingForLaunchCancel": "Cancelar",
```

- [ ] **Step 2: Add the same keys to `app_en.arb`**

Insert the English equivalents at the corresponding spot in `movile_app/lib/l10n/app_en.arb`:

```json
  "speedSetupCountdownAuto": "Auto",
  "speedWaitingForLaunchTitle": "Waiting for launch…",
  "speedWaitingForLaunchSubtitle": "Timing will start when the vehicle accelerates",
  "speedWaitingForLaunchCancel": "Cancel",
```

- [ ] **Step 3: Regenerate the localizations**

Run:
```powershell
cd movile_app
flutter gen-l10n
```
Expected: no errors; `lib/l10n/app_localizations*.dart` is regenerated with the four new getters.

- [ ] **Step 4: Sanity check — the generated files expose the new keys**

Run:
```powershell
cd movile_app
grep -n "speedWaitingForLaunchTitle\|speedSetupCountdownAuto" lib/l10n/app_localizations.dart
```
Expected: matches found on abstract getter declarations.

- [ ] **Step 5: Commit**

```bash
git add movile_app/lib/l10n/app_en.arb movile_app/lib/l10n/app_es.arb movile_app/lib/l10n/app_localizations.dart movile_app/lib/l10n/app_localizations_en.dart movile_app/lib/l10n/app_localizations_es.dart
git commit -m "i18n(speed): add auto-launch strings"
```

---

## Task 4: Setup screen — "Auto" chip

**Files:**
- Modify: `movile_app/lib/src/features/speed/speed_setup_screen.dart`
- Test: `movile_app/test/features/speed/speed_setup_screen_test.dart`

**Interfaces consumed:** `AppLocalizations.speedSetupCountdownAuto` (Task 3).

**Interfaces produced:** the `SpeedSetupResult.countdownSeconds` returned by the setup screen may now be `0` (auto).

- [ ] **Step 1: Write the failing test — Auto chip yields countdownSeconds==0**

Append to `movile_app/test/features/speed/speed_setup_screen_test.dart` inside `main()`:

```dart
  testWidgets('Selecting the Auto chip yields countdownSeconds == 0',
      (tester) async {
    // The garage/metric prerequisites for the Continue button are covered
    // by the widget's construction contract elsewhere; we drive the chip
    // directly and inspect the wired value by capturing SetupResult via
    // a stub that never actually completes the button (the flow through
    // the button is not what we assert here).
    SpeedSetupResult? captured;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SpeedSetupScreen(
        garageService: null,
        onContinue: (r) => captured = r,
      ),
    ));
    await tester.pumpAndSettle();

    // Tap the "Auto" chip.
    final autoChip = find.widgetWithText(ChoiceChip, 'Auto');
    expect(autoChip, findsOneWidget,
        reason: 'the setup must render a chip labeled "Auto"');
    await tester.tap(autoChip);
    await tester.pumpAndSettle();

    // The chip must now be selected.
    final chip = tester.widget<ChoiceChip>(autoChip);
    expect(chip.selected, isTrue);

    // Continue is still disabled without a vehicle/metric, but our
    // assertion is about the chip's stored value. Poke internal state
    // through the public callback by simulating a scenario where the
    // callback fires — we can't, so we assert the visible selection is
    // correctly on "Auto" and rely on the controller test to prove the
    // 0 value is honored.
    expect(captured, isNull,
        reason: 'callback fires only via Continue, which is disabled here');
  });
```

- [ ] **Step 2: Run the test — expect failure**

Run:
```powershell
cd movile_app
flutter test test/features/speed/speed_setup_screen_test.dart
```
Expected: the `Auto` chip is not found; the test fails.

- [ ] **Step 3: Add the `0` value to the chips list**

In `movile_app/lib/src/features/speed/speed_setup_screen.dart`, replace `_countdownChips`:

```dart
  Widget _countdownChips(AppLocalizations l) {
    return Wrap(
      spacing: 8,
      children: [0, 3, 5, 10].map((n) {
        final label = n == 0 ? l.speedSetupCountdownAuto : l.speedSetupSecondsValue(n);
        return ChoiceChip(
          label: Text(label),
          selected: _countdown == n,
          onSelected: (_) => setState(() => _countdown = n),
        );
      }).toList(),
    );
  }
```

The default value of `_countdown` (`3`) stays unchanged.

- [ ] **Step 4: Run the test — expect pass**

Run:
```powershell
cd movile_app
flutter test test/features/speed/speed_setup_screen_test.dart
```
Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add movile_app/lib/src/features/speed/speed_setup_screen.dart movile_app/test/features/speed/speed_setup_screen_test.dart
git commit -m "feat(speed): add Auto chip (countdownSeconds==0) to speed setup"
```

---

## Task 5: `WaitingForLaunchOverlay` widget

**Files:**
- Create: `movile_app/lib/src/features/speed/widgets/waiting_for_launch_overlay.dart`
- Test: `movile_app/test/features/speed/waiting_for_launch_overlay_test.dart`

**Interfaces consumed:** the l10n keys from Task 3.

**Interfaces produced:**
- `class WaitingForLaunchOverlay extends StatelessWidget` with `final VoidCallback onCancel;` in its constructor.

- [ ] **Step 1: Write the failing widget test**

Create `movile_app/test/features/speed/waiting_for_launch_overlay_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitway_mobile/l10n/app_localizations.dart';
import 'package:splitway_mobile/src/features/speed/widgets/waiting_for_launch_overlay.dart';

void main() {
  testWidgets('renders title, subtitle, and a cancel button', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: WaitingForLaunchOverlay(onCancel: () => cancelled = true),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Waiting for launch…'), findsOneWidget);
    expect(
      find.text('Timing will start when the vehicle accelerates'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    expect(cancelled, isTrue,
        reason: 'tapping the Cancel button must invoke the callback');
  });
}
```

- [ ] **Step 2: Run the test — expect failure**

Run:
```powershell
cd movile_app
flutter test test/features/speed/waiting_for_launch_overlay_test.dart
```
Expected: import fails because the file doesn't exist.

- [ ] **Step 3: Create the overlay widget**

Write `movile_app/lib/src/features/speed/widgets/waiting_for_launch_overlay.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:splitway_mobile/l10n/app_localizations.dart';

class WaitingForLaunchOverlay extends StatelessWidget {
  const WaitingForLaunchOverlay({super.key, required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(
                Icons.rocket_launch,
                size: 96,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              Text(
                l.speedWaitingForLaunchTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l.speedWaitingForLaunchSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l.speedWaitingForLaunchCancel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test — expect pass**

Run:
```powershell
cd movile_app
flutter test test/features/speed/waiting_for_launch_overlay_test.dart
```
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add movile_app/lib/src/features/speed/widgets/waiting_for_launch_overlay.dart movile_app/test/features/speed/waiting_for_launch_overlay_test.dart
git commit -m "feat(speed): add WaitingForLaunchOverlay widget"
```

---

## Task 6: Session screen — render the overlay and use `displayedElapsed`

**Files:**
- Modify: `movile_app/lib/src/features/speed/speed_session_screen.dart`

**Interfaces consumed:**
- `SpeedScreenPhase.waitingForLaunch`, `SpeedSessionController.displayedElapsed`, `SpeedSessionController.cancelWaiting()` (Task 2).
- `WaitingForLaunchOverlay` (Task 5).

**Interfaces produced:** none new — the screen wires existing pieces together.

- [ ] **Step 1: Import the new overlay**

At the top of `speed_session_screen.dart`, next to the existing widget imports:

```dart
import 'widgets/waiting_for_launch_overlay.dart';
```

- [ ] **Step 2: Render the overlay when the controller is waiting**

In the `Stack` inside `build`, add this branch right after the `FalseStartOverlay` branch:

```dart
            if (c.phase == SpeedScreenPhase.waitingForLaunch)
              WaitingForLaunchOverlay(
                onCancel: () async {
                  await c.cancelWaiting();
                  if (context.mounted) widget.onCancelled();
                },
              ),
```

- [ ] **Step 3: Switch the chronometer to `displayedElapsed`**

In `_speedHeader`, replace the second `ValueListenableBuilder<Duration>` block:

```dart
          ValueListenableBuilder<Duration>(
            valueListenable: c.service.elapsed,
            builder: (_, __, ___) {
              final d = c.displayedElapsed;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatChrono(d),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'mm:ss.SSS',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              );
            },
          ),
```

The `ValueListenableBuilder` still listens to `service.elapsed` so the widget ticks at the sensor rate; the displayed value comes from the controller's getter.

- [ ] **Step 4: Run the full speed feature test suite**

Run:
```powershell
cd movile_app
flutter test test/features/speed test/services/speed
```
Expected: everything still passes.

- [ ] **Step 5: Static analysis**

Run:
```powershell
cd movile_app
flutter analyze lib/src/features/speed lib/src/services/speed
```
Expected: `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add movile_app/lib/src/features/speed/speed_session_screen.dart
git commit -m "feat(speed): render WaitingForLaunchOverlay and use displayedElapsed on session screen"
```

---

## Task 7: Full-suite regression + manual smoke check

**Files:** none modified.

- [ ] **Step 1: Run the full mobile test suite**

Run:
```powershell
cd movile_app
flutter test
```
Expected: all tests pass.

- [ ] **Step 2: Run analyzer at project scope**

Run:
```powershell
cd movile_app
flutter analyze
```
Expected: no new warnings introduced by this feature.

- [ ] **Step 3: Manual smoke — countdown regression**

On a device or emulator, open the speed setup, leave countdown at `3s`, pick a vehicle + metric, and confirm the countdown → running flow still works (3 beeps, GO, splits register).

- [ ] **Step 4: Manual smoke — auto-launch happy path**

Same setup but select the `Auto` chip. Confirm:
- "Waiting for launch…" overlay appears immediately after Start.
- No beeps play.
- Header chronometer shows `00:00.000` while waiting.
- Accelerating the vehicle (or shaking the phone above threshold for >100 ms) transitions the screen to running, chrono starts ticking from zero, splits populate as expected.

- [ ] **Step 5: Manual smoke — cancel from waiting**

Same setup with `Auto`. Tap the `Cancel` button in the overlay. Expected: navigates back to the previous screen (routes) and no session is persisted.

- [ ] **Step 6: If everything is green, no extra commit — the feature is complete.**

---

## Self-Review (against the spec)

- **Spec § "Nueva fase en el controller"** → Task 2 Steps 3–6 add `waitingForLaunch`, `_waitForLaunch`, `_onMotionDetected`, `cancelWaiting`, and the retry branch. ✓
- **Spec § "Cambios en `SpeedMeasurementService`"** → Task 1 Steps 3–5 add the notifier, wire the setter and reset. ✓
- **Spec § "False-start"** → Auto path never enters `SpeedPhase.armed`, so the false-start check is inert; no code change needed. ✓
- **Spec § "Setup screen"** → Task 4 changes `_countdownChips` to `[0, 3, 5, 10]` with the `Auto` label. ✓
- **Spec § "Session screen"** → Task 6 wires the overlay and `displayedElapsed`. ✓
- **Spec § "Nuevo widget `waiting_for_launch_overlay.dart`"** → Task 5. ✓
- **Spec § "Localización"** → Task 3 covers all four keys in both locales, plus `flutter gen-l10n`. ✓
- **Spec § "Cronómetro del header"** → Task 2 Step 5 (`displayedElapsed`) plus Task 6 Step 3 (screen wiring) implement the offset compensation. ✓
- **Spec § "Persistencia y compatibilidad"** → No DAO/model changes needed (persisted `countdownSeconds` field is already `int`); the spec's note about the history label is moot because `speed_session_detail_screen.dart` does not display `countdownSeconds`. ✓
- **Spec § "Tests"** → Task 1 (service), Task 2 (controller happy/cancel/regression), Task 4 (setup chip), Task 5 (overlay widget). ✓

No placeholders. Types consistent: `motionDetected: ValueNotifier<bool>` referenced identically across Tasks 1 and 2; `waitingForLaunch` enum value and `cancelWaiting()`, `displayedElapsed` names identical across Tasks 2 and 6.
