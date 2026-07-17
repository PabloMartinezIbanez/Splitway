# Test de velocidad — Modo "esperar arranque" (auto)

**Fecha:** 2026-07-17
**Feature:** Speed test → Setup + Session
**Archivos principales:**
- `lib/src/features/speed/speed_setup_screen.dart`
- `lib/src/features/speed/speed_session_controller.dart`
- `lib/src/features/speed/speed_session_screen.dart`
- `lib/src/features/speed/widgets/` (nuevo `waiting_for_launch_overlay.dart`)
- `lib/src/services/speed/speed_measurement_service.dart`
- `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`

## Problema

Hoy el test de velocidad obliga a elegir una cuenta atrás fija de 3, 5 o 10 segundos. Para pruebas en carretera donde el conductor no puede sincronizar su salida con un beep (ej. tramo largo, tráfico, cabina), la cuenta atrás estorba: o se pierde la ventana de arranque o se genera un false-start.

Se quiere un modo alternativo que no cuente hacia atrás y simplemente empiece a registrar la sesión cuando detecta que el coche acelera.

**Nota importante sobre el cronómetro:** los splits (0-100, 60ft, ¼ milla…) ya se miden desde el primer movimiento sostenido real (`_motionStartTime` en `SpeedMeasurementService._detectMilestones`), no desde el "Go!" del countdown. Este modo no cambia la precisión del cronometraje — cambia únicamente **cuándo se muestra la fase de running al usuario** y elimina los beeps de cuenta atrás.

## Solución

Un cuarto chip "Auto" en la sección de cuenta atrás del setup. Cuando se elige, se salta el countdown y la detección de false-start; la sesión entra en una fase nueva `waitingForLaunch` que se resuelve automáticamente cuando el servicio detecta movimiento sostenido.

### Convención de valor

`SpeedSetupResult.countdownSeconds`, `SpeedSessionController.countdownSeconds` y el `countdownSeconds` persistido en `SpeedSession` siguen siendo `int`. **Valor `0` = modo auto** (esperar arranque). Valores `3`, `5`, `10` = countdown clásico. Elegido `0` frente a `int?` o un enum por minimizar el impacto en el modelo persistido y en el histórico.

### Nueva fase en el controller

```dart
enum SpeedScreenPhase {
  ready,
  arming,
  countdown,
  waitingForLaunch, // ← nueva
  running,
  falseStart,
  finished,
}
```

Flujo cuando `countdownSeconds == 0`:

1. `begin()` preload beep + suscribe `falseStartStream` (se suscribe igual pero nunca disparará; ver siguiente punto).
2. **Se salta `_arm()`** — no hay fase `arming` ni `countdown` ni beeps.
3. Se llama directamente `service.liveStart()` (arranca en `SpeedPhase.running`, activando la detección de movimiento sostenido).
4. Fase pasa a `waitingForLaunch`, se notifica al UI.
5. Cuando `service.motionDetected.value` pasa a `true`, el controller marca `startedAt = DateTime.now()` y transita a `running`.
6. A partir de ahí el flujo es idéntico al actual (`_maybeFinish` sobre `service.results`).

`retry()`: cuando `countdownSeconds == 0`, en vez de re-armar countdown, vuelve a `waitingForLaunch` (parar sensores + `liveStart` + resetear notifier).

Nuevo método público `cancelWaiting()` para el botón "Cancelar" del overlay:
- Sólo válido si `phase == waitingForLaunch`.
- Llama `service.liveStop()` y deja el controller en un estado terminal (`ready`) — la screen usa el callback `onCancelled` ya existente para navegar atrás.

### Cambios en `SpeedMeasurementService`

Añadir un `ValueNotifier<bool> motionDetected = ValueNotifier(false)` como campo público, en la misma sección que `results`/`phase`/`instantaneousKmh`/`elapsed`. Se dispone en `_closeNotifiers()`.

Dentro de `_detectMilestones`, en la rama que fija `_motionStartTime`:

```dart
if (sustained >= _reactionSustain) {
  _motionStartTime = _reactionCandidateTime;
  motionDetected.value = true;   // ← nuevo
  if (targets.contains(SpeedMetric.reactionTime)) {
    updated[SpeedMetric.reactionTime] =
        _reactionCandidateTime!.inMicroseconds / 1e6;
  }
}
```

Y en `start()` (que ya resetea `_motionStartTime`) resetear también `motionDetected.value = false` para que `retry()` funcione limpio.

Con esto el controller puede escuchar el notifier sin duplicar el umbral (0.5 km/h / 1.0 m/s² / 100 ms sustain) que ya vive en el servicio.

### False-start

En modo auto no hay fase `arming` ni ventana previa al arranque: la aceleración **es** el inicio válido. No se dispara `_checkFalseStart` porque el servicio pasa directamente a `SpeedPhase.running` (donde `_checkFalseStart` no se ejecuta — ver switch en `_onSample`). La suscripción a `falseStartStream` sigue activa pero inerte, lo que evita ramificar el código de `begin()`.

## UI

### Setup screen (`speed_setup_screen.dart`)

El `Wrap` de `_countdownChips` cambia de `[3, 5, 10]` a `[0, 3, 5, 10]`. El chip con valor `0` muestra un texto localizado "Auto" (nueva clave `speedSetupCountdownAuto`) en vez de "0 s". Los demás siguen usando `l.speedSetupSecondsValue(n)`.

El valor por defecto de `_countdown` se queda en `3` (comportamiento actual).

### Session screen (`speed_session_screen.dart`)

En el `Stack` que ya renderiza `CountdownOverlay` y `FalseStartOverlay`, añadir:

```dart
if (c.phase == SpeedScreenPhase.waitingForLaunch)
  WaitingForLaunchOverlay(onCancel: widget.onCancelled),
```

El velocímetro (km/h) del header se deja visible — útil para confirmar que el GPS está vivo y reporta 0 km/h antes de arrancar. El `_body` de métricas también se deja renderizando (guiones de "sin dato") hasta el arranque.

**Cronómetro del header:** `service.elapsed` empieza a tickar en cuanto se llama `liveStart()`, es decir durante todo `waitingForLaunch`. Los splits internos se miden desde `_motionStartTime` y no se ven afectados, pero el `elapsed` crudo lleva acumulado el tiempo de espera y no puede mostrarse tal cual — sin corrección, el chrono saltaría de `00:00.000` a p.ej. `00:05.000` en el instante del launch.

Solución en el controller: al detectar motion, capturar `_launchElapsedOffset = service.elapsed.value` como `Duration`. Exponer un getter público `Duration displayedElapsed` que:
- devuelve `Duration.zero` mientras `phase == waitingForLaunch`,
- devuelve `service.elapsed.value - _launchElapsedOffset` en `running` / `finished`,
- devuelve `service.elapsed.value` en modo countdown clásico (offset = 0).

En countdown clásico esto no cambia el comportamiento porque `_go()` ya hace `liveStop()` + `liveStart()`, dejando `service.elapsed` reseteado — el offset siempre es 0.

En el header widget, sustituir el `ValueListenableBuilder<Duration>` que escuchaba `c.service.elapsed` por uno que escuche igualmente el notifier del servicio (para el tick) pero renderice `c.displayedElapsed`. Al `retry()` desde el modo auto, resetear también `_launchElapsedOffset = null`.

### Nuevo widget `waiting_for_launch_overlay.dart`

Overlay a pantalla completa con fondo semi-opaco, sobre `Colors.black`. Contenido centrado:

- Icono grande (ej. `Icons.directions_car_filled` o `Icons.rocket_launch`).
- Título: `speedWaitingForLaunchTitle`.
- Subtítulo: `speedWaitingForLaunchSubtitle`.
- Botón `OutlinedButton` "Cancelar" que llama `onCancel`.

Consistente en estilo con `CountdownOverlay` y `FalseStartOverlay` existentes.

## Localización

Nuevas claves en `app_en.arb` / `app_es.arb`:

| Clave | EN | ES |
|-------|----|----|
| `speedSetupCountdownAuto` | `Auto` | `Auto` |
| `speedWaitingForLaunchTitle` | `Waiting for launch…` | `Esperando arranque…` |
| `speedWaitingForLaunchSubtitle` | `Timing will start when the vehicle accelerates` | `El cronómetro empezará cuando el coche acelere` |
| `speedWaitingForLaunchCancel` | `Cancel` | `Cancelar` |

Regenerar `app_localizations*.dart` con `flutter gen-l10n`.

## Persistencia y compatibilidad

`SpeedSession.countdownSeconds` guarda `0` para sesiones en modo auto. Sesiones antiguas (3/5/10) no se ven afectadas. La UI del histórico (`history_screen.dart`) que ya lee este campo debe interpretarse: `0` → "Auto"; valores > 0 → "Ns". Si hoy se muestra el valor crudo, añadir un helper de formateo en el mismo sitio donde se lea.

## Tests

### `speed_measurement_service_test.dart` (extender)

- Con `SpeedMeasurementService.forTesting`, tras `liveStart` (o `start` seguido de `debugInjectSample`) inyectar muestras por debajo del umbral (`speedKmh < 0.5`, `accelMs2 < 1.0`) durante > 100 ms → `motionDetected.value == false`.
- Repetir con muestras sostenidas por encima del umbral durante ≥ 100 ms → `motionDetected.value == true`.
- Tras `start()` (o `arm`), `motionDetected.value == false` (reset entre sesiones).

### `speed_session_controller_test.dart` (extender o crear)

- `countdownSeconds == 0`: al llamar `begin()`, la fase salta directamente a `waitingForLaunch` sin pasar por `arming` ni `countdown`. No se llama a `beep.tick()` ni `beep.go()` (verificar con un `BeepPlayer` fake o spy).
- Con la fase en `waitingForLaunch`, cuando el `motionDetected` del servicio pasa a `true` → la fase transita a `running` y `startedAt` queda seteado.
- `cancelWaiting()` desde `waitingForLaunch` deja el servicio parado y no dispara `notifyListeners()` con `phase == running`.
- `countdownSeconds == 3` (regresión): comportamiento actual intacto — `arming → countdown → running` y beeps al ritmo esperado.

### Setup widget test

- Al pulsar el chip "Auto" y luego `speed-continue`, el `SpeedSetupResult` recibido en el callback trae `countdownSeconds == 0`.

## No incluido (fuera de scope)

- Cambios en el umbral de detección de movimiento (ya cubierto por spec previa de calibración de reacción).
- Beep de confirmación al detectar arranque (usuario descartó).
- Toggle independiente del beep — se decide todo con el chip.
- Migración de sesiones antiguas.
