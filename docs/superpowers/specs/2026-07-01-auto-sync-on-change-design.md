# Auto-sync por cambios + texto de estado (sin botón)

**Fecha:** 2026-07-01
**Estado:** Aprobado (diseño)

## Objetivo

Cambiar el modelo de sincronización con la nube:

1. **Eliminar el botón "Sincronizar ahora"** del drawer.
2. Mostrar un **texto pequeño** que informe si los datos están sincronizados con la
   nube o si aún hay cambios pendientes de subir.
3. **Sincronizar automáticamente** cada vez que haya algo que subir, con un
   **debounce de 1 minuto** que se reinicia con cada cambio, de forma que varias
   ediciones seguidas se suban juntas.

## Contexto actual

- `SyncService` (`movile_app/lib/src/services/sync/sync_service.dart`):
  - Timer periódico cada 5 min (`startPeriodicSync`), sync inicial inmediato,
    sync al recuperar conectividad, y `sync()` manual.
  - `sync()` es bidireccional (push local→remoto + pull remoto→local),
    last-write-wins por `updated_at`.
  - Estado `SyncStatus { idle, syncing, error, success, offline }` + `lastSyncedAt`.
- `LocalDraftRepository` expone un stream broadcast `changes` que emite
  `_changes.add(null)` en **cada escritura local** (save/update/delete de
  routes, sessions, free rides; setter de `userId`; purgas; `clearUserData`).
- La UI de sync vive en el drawer, en `_SyncSection`
  (`movile_app/lib/src/shared/widgets/app_drawer.dart`): punto de color +
  etiqueta + botón con gradiente. Se renderiza dentro de un `ListenableBuilder`
  sobre `syncService`.
- l10n generada desde `app_es.arb` / `app_en.arb`. Claves existentes:
  `drawerSyncSynced`, `drawerSyncSyncedNow`, `drawerSyncSyncedMinutes`,
  `drawerSyncSyncedAt`, `drawerSyncSyncing`, `drawerSyncError`,
  `drawerSyncOffline`, `drawerSyncNow`.
- Tests: existe `test/services/sync/sync_planner_test.dart` (lógica pura). No hay
  ningún test que dependa de `_SyncSection` ni de `drawerSyncNow`.

## Decisiones tomadas

- **Descarga periódica:** se **mantiene** el timer de 5 min (trae cambios de otros
  dispositivos y actúa de red de seguridad).
- **Debounce:** ventana **deslizante** — cada nuevo cambio reinicia el temporizador
  de 1 min.
- **Estados del texto:** conjunto completo (sincronizado / cambios pendientes /
  sincronizando / sin conexión / error).

## Diseño

### 1. `SyncService` — auto-sync disparado por cambios

Se aprovecha el stream `local.changes` como señal de "hay algo que subir".

Cambios en `SyncService`:

- **Constructor:** nuevo parámetro `Duration autoSyncDebounce = const Duration(minutes: 1)`.
- **Estado nuevo:** `bool _hasPendingChanges = false;` con getter público
  `bool get hasPendingChanges`.
- **Suscripción:** en el constructor, suscribirse a `local.changes`
  (junto a la suscripción de conectividad ya existente). Guardar
  `StreamSubscription<void>? _changesSubscription` y `Timer? _debounceTimer`.
- **Handler `_onLocalChange()`:**
  - Si `_status == SyncStatus.syncing` → **return** (ignora las escrituras que el
    propio sync provoca vía `changes`: pulls remoto→local, guardado batch de
    thumbnails, borrados de reconciliación). Esto evita el bucle de auto-disparo
    y los falsos "pendientes".
  - En caso contrario:
    - `_hasPendingChanges = true;` y `notifyListeners();`
    - Reiniciar `_debounceTimer` a `autoSyncDebounce`. Al disparar:
      `if (_isConnected) sync();`
- **En `sync()`:** en el camino de éxito, `_hasPendingChanges = false;` (antes de
  `notifyListeners()`). En error u offline **no** se limpia (queda pendiente y lo
  reintentan el timer periódico, la reconexión o el siguiente cambio).
- **Ciclo de vida:** en `dispose()`, cancelar `_debounceTimer` y
  `_changesSubscription` (además de lo ya cancelado).

Se mantienen sin cambios: `startPeriodicSync` (5 min + sync inicial),
`_onConnectivityChanged`, `stopPeriodicSync`, los métodos `delete*`, y la lógica
bidireccional de `_doSync`.

**Limitación conocida (documentada):** un cambio del usuario que ocurra justo
durante un `sync()` en vuelo (~1–2 s) se ignora porque no se puede distinguir, a
nivel de stream, de las escrituras que el sync produce. Lo recoge el siguiente
cambio local o el sync periódico de 5 min. Se acepta por simplicidad.

### 2. Texto de estado en el drawer (`_SyncSection`)

- **Eliminar el botón:** quitar el bloque `SizedBox`/`DecoratedBox`/`Material`/
  `InkWell` con gradiente (el botón "Sincronizar ahora") y el `SizedBox(height: 10)`
  previo. Queda únicamente la fila `Row` con el punto de color + texto pequeño.
- **Mapeo punto/etiqueta** (prioridad de arriba abajo):
  - `offline` → `drawerSyncOffline` — naranja `0xFFFF9800`
  - `syncing` → `drawerSyncSyncing` — azul `0xFF42A5F5`
  - `error` → `drawerSyncError` — rojo `0xFFEF5350`
  - si no, y `hasPendingChanges == true` → `drawerSyncPending` (nueva) — ámbar `0xFFFFB300`
  - si no → etiqueta idle actual (`_idleLabel`: SINCRONIZADO / · ahora / hace N min /
    a las HH:MM) — verde `0xFF4CAF50`
- **Extracción para testeo:** mover la selección `(Color, String)` a una función
  pura, en el mismo estilo que `SyncPlanner`:

  ```dart
  (Color, String) syncStatusDisplay(
    SyncStatus status,
    bool hasPendingChanges,
    DateTime? lastSyncedAt,
    AppLocalizations l,
  )
  ```

  Ubicación propuesta: helper de nivel de librería en el propio `app_drawer.dart`
  (o un archivo hermano `sync_status_display.dart` en `shared/widgets/`), sin
  dependencia de `SyncService` para poder testearla con valores directos.
  `_SyncSection.build` la invoca pasando `syncService.status`,
  `syncService.hasPendingChanges` y `syncService.lastSyncedAt`.
- El `_SyncSection` sigue envuelto en el `ListenableBuilder` sobre `syncService`,
  de modo que el texto se actualiza en vivo cuando cambian estado o pendientes.

### 3. l10n

- **Añadir** `drawerSyncPending` a `app_es.arb` ("CAMBIOS PENDIENTES") y
  `app_en.arb` ("PENDING CHANGES"), y regenerar (`flutter gen-l10n` o el flujo del
  proyecto).
- **Eliminar** `drawerSyncNow` de ambos ARB y sus referencias generadas (queda sin
  uso al retirar el botón).

### 4. Tests (TDD)

1. **Función pura `syncStatusDisplay`** (nuevo test): verificar la etiqueta y el
   color devueltos para cada caso:
   - offline → etiqueta offline
   - syncing → etiqueta syncing
   - error → etiqueta error
   - idle + `hasPendingChanges` → etiqueta pending
   - idle sin pendientes, `lastSyncedAt` null / reciente / minutos → etiqueta idle
     correspondiente
   - `success` con pendientes false → etiqueta idle (no pending)
2. **`SyncService` (debounce/pending)** — verificar viabilidad de instanciación en
   test respecto a la suscripción `Connectivity().onConnectivityChanged` del
   constructor:
   - Un evento en `local.changes` marca `hasPendingChanges = true` y programa un
     `sync()` tras `autoSyncDebounce` (usar un debounce corto y `FakeAsync`/tiempo
     controlado).
   - Cambios sucesivos reinician el temporizador (solo un sync al final).
   - Eventos emitidos mientras `status == syncing` se ignoran (no reprograman ni
     marcan pendiente).
   - Tras un `sync()` con éxito, `hasPendingChanges` vuelve a `false`.

   Si instanciar `SyncService` en test resulta inviable por el plugin de
   conectividad, el plan definirá la vía (inyectar el stream de conectividad, o
   cubrir la lógica de debounce con un test de más bajo nivel). La función pura del
   punto 1 queda como cobertura garantizada del texto de estado.

## Fuera de alcance

- Persistir `hasPendingChanges` entre reinicios (en el arranque, el sync inicial ya
  sube lo pendiente local por last-write-wins).
- Mostrar el estado de sync en otras pantallas fuera del drawer.
- Cambiar la estrategia last-write-wins ni la lógica de `_doSync`.

## Archivos afectados

- `movile_app/lib/src/services/sync/sync_service.dart` — debounce + pending +
  suscripción a `changes`.
- `movile_app/lib/src/shared/widgets/app_drawer.dart` — quitar botón, texto de
  estado, función pura `syncStatusDisplay` (o archivo hermano).
- `movile_app/lib/l10n/app_es.arb`, `app_en.arb` (+ generados) — `drawerSyncPending`,
  quitar `drawerSyncNow`.
- Tests nuevos bajo `movile_app/test/` para la función pura y (si viable) el
  debounce de `SyncService`.
