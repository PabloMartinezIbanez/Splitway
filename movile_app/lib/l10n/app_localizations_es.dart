// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Splitway';

  @override
  String get appTagline => 'Cronómetro inteligente para rutas';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonBack => 'Volver';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonClose => 'Entendido';

  @override
  String get commonRefresh => 'Recargar';

  @override
  String get commonDiscard => 'Descartar';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageSpanish => 'Español';

  @override
  String get navEditor => 'Editor';

  @override
  String get navSession => 'Sesión';

  @override
  String get navHistory => 'Historial';

  @override
  String get navRoutes => 'Rutas';

  @override
  String get drawerMenu => 'Menú';

  @override
  String get drawerDefaultUser => 'Usuario';

  @override
  String get drawerSettings => 'Configuración';

  @override
  String get drawerStats => 'Estadísticas';

  @override
  String get drawerHelp => 'Ayuda';

  @override
  String get drawerSignOut => 'Cerrar sesión';

  @override
  String get drawerSignIn => 'Iniciar sesión';

  @override
  String drawerAppVersion(String version) {
    return 'v$version';
  }

  @override
  String get drawerSyncSynced => 'SINCRONIZADO';

  @override
  String get drawerSyncSyncedNow => 'SINCRONIZADO · ahora';

  @override
  String drawerSyncSyncedMinutes(int minutes) {
    return 'SINCRONIZADO · hace $minutes min';
  }

  @override
  String drawerSyncSyncedAt(String time) {
    return 'SINCRONIZADO · $time';
  }

  @override
  String get drawerSyncSyncing => 'SINCRONIZANDO…';

  @override
  String get drawerSyncError => 'ERROR DE SYNC';

  @override
  String get drawerSyncOffline => 'SIN CONEXIÓN';

  @override
  String get drawerSyncPending => 'CAMBIOS PENDIENTES';

  @override
  String get drawerProfile => 'Perfil';

  @override
  String get loginBannerDefault => 'Inicia sesión para continuar';

  @override
  String get loginEmailHint => 'Email';

  @override
  String get loginPasswordHint => 'Contraseña';

  @override
  String get loginEmailRequired => 'Introduce un email';

  @override
  String get loginEmailInvalid => 'Email no válido';

  @override
  String get loginPasswordRequired => 'Introduce una contraseña';

  @override
  String get loginPasswordMinLength => 'Mínimo 6 caracteres';

  @override
  String get loginConfirmPasswordHint => 'Confirmar contraseña';

  @override
  String get loginPasswordMismatch => 'Las contraseñas no coinciden';

  @override
  String get loginSignInButton => 'Iniciar sesión';

  @override
  String get loginSignUpButton => 'Crear cuenta';

  @override
  String get loginOrSeparator => '— o —';

  @override
  String get loginContinueWithGoogle => 'Continuar con Google';

  @override
  String get loginToggleToSignUp => '¿No tienes cuenta? ';

  @override
  String get loginToggleToSignIn => '¿Ya tienes cuenta? ';

  @override
  String get loginToggleSignUpAction => 'Regístrate';

  @override
  String get loginToggleSignInAction => 'Inicia sesión';

  @override
  String get loginSkipButton => 'Continuar sin cuenta';

  @override
  String get loginNicknameHint => 'Apodo';

  @override
  String get loginNicknameRequired => 'Introduce un apodo';

  @override
  String get loginNicknameMinLength => 'Mínimo 2 caracteres';

  @override
  String get loginConfirmationTitle => '¡Revisa tu correo!';

  @override
  String loginConfirmationBody(String email) {
    return 'Te hemos enviado un enlace de confirmación a\n$email\n\nHaz clic en el enlace para activar tu cuenta y poder iniciar sesión.';
  }

  @override
  String get authErrorGoogleToken => 'No se pudo obtener el token de Google.';

  @override
  String get authErrorEmailAlreadyRegistered =>
      'Este email ya está registrado. Inicia sesión.';

  @override
  String get authErrorInvalidCredentials => 'Email o contraseña incorrectos.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Confirma tu email antes de iniciar sesión.';

  @override
  String get authErrorPasswordTooShort =>
      'La contraseña debe tener al menos 6 caracteres.';

  @override
  String get authErrorNoConnection => 'Sin conexión. Inténtalo de nuevo.';

  @override
  String get authErrorUnexpected => 'Error inesperado. Inténtalo de nuevo.';

  @override
  String get authErrorBanned => 'Tu cuenta está baneada.';

  @override
  String authErrorBannedUntil(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Tu cuenta está baneada hasta el $dateString.';
  }

  @override
  String get loginForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get loginForgotPasswordTitle => 'Restablecer contraseña';

  @override
  String get loginForgotPasswordBody =>
      'Introduce tu email y te enviaremos un enlace para restablecer tu contraseña.';

  @override
  String get loginForgotPasswordButton => 'Enviar enlace';

  @override
  String loginForgotPasswordSuccess(String email) {
    return 'Te enviamos un enlace a $email. Revisa tu bandeja de entrada.';
  }

  @override
  String get loginForgotPasswordError =>
      'No se pudo enviar el email. Inténtalo de nuevo.';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileAvatarUpdated => 'Avatar actualizado';

  @override
  String get profileErrorUnexpected =>
      'No se pudo actualizar el avatar. Inténtalo de nuevo.';

  @override
  String get profileNicknameUpdated => 'Apodo actualizado';

  @override
  String get profileErrorCooldown =>
      'El apodo solo se puede cambiar tras el tiempo de espera.';

  @override
  String get profileBioUpdated => 'Biografía actualizada';

  @override
  String get profileChangeAvatar => 'Cambiar avatar';

  @override
  String get profileNicknameLabel => 'Apodo';

  @override
  String get profileNicknameRequired => 'Introduce un apodo';

  @override
  String get profileNicknameMinLength => 'Mínimo 2 caracteres';

  @override
  String get profileNicknameTooLong => 'Máximo 30 caracteres';

  @override
  String get profileBioLabel => 'Biografía';

  @override
  String get profileBioHint => 'Cuenta algo sobre ti';

  @override
  String profileNicknameCooldownDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String profileNicknameCooldownHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours horas',
      one: '1 hora',
    );
    return '$_temp0';
  }

  @override
  String get profileNicknameCooldown => 'Cambio de apodo disponible en';

  @override
  String get profileEmailLabel => 'Correo electrónico';

  @override
  String get profileDateOfBirthLabel => 'Fecha de nacimiento';

  @override
  String get loginDateOfBirthHint => 'Fecha de nacimiento';

  @override
  String get onboardingTitle => 'Completa tu perfil';

  @override
  String get onboardingDescription =>
      'Necesitamos algunos datos para terminar de configurar tu cuenta. La contraseña te permitirá iniciar sesión también con email.';

  @override
  String get onboardingSubmit => 'Guardar y continuar';

  @override
  String get onboardingSubmitLoading => 'Guardando…';

  @override
  String get onboardingDobInvalid => 'Debes tener al menos 13 años.';

  @override
  String get onboardingProfileFailed =>
      'No se pudo guardar el perfil. Inténtalo de nuevo.';

  @override
  String get onboardingPasswordFailed => 'No se pudo establecer la contraseña.';

  @override
  String get onboardingPasswordMinLength => 'Mínimo 8 caracteres.';

  @override
  String get editorTitle => 'Editor de rutas';

  @override
  String get editorNewRouteTooltip => 'Nueva ruta';

  @override
  String get editorNewRouteButton => 'Nueva ruta';

  @override
  String get editorNoRoutesTitle => 'Aún no tienes rutas';

  @override
  String get editorNoRoutesMessage =>
      'Crea tu primera ruta para empezar a cronometrar.';

  @override
  String get editorSectorsLabel => 'Sectores';

  @override
  String editorSectorCenter(String lat, String lng) {
    return 'Centro: $lat, $lng';
  }

  @override
  String get editorStartFinishLabel => 'Inicio / meta';

  @override
  String editorCreatedAt(String date) {
    return 'Creada el $date';
  }

  @override
  String get editorDeleteRouteButton => 'Eliminar ruta';

  @override
  String get editorDeleteRouteTitle => 'Eliminar ruta';

  @override
  String editorDeleteRouteConfirm(String routeName) {
    return '¿Borrar \"$routeName\" y todas sus sesiones?';
  }

  @override
  String get editorModeAppendPath => 'Trazado';

  @override
  String get editorModeStartGate => 'Inicio / meta';

  @override
  String get editorModeSectorGate => 'Añadir sector';

  @override
  String editorDrawingTitle(String draftName) {
    return 'Dibujando: $draftName';
  }

  @override
  String get editorCancelTooltip => 'Cancelar';

  @override
  String get editorCancelDrawingTitle => 'Cancelar dibujo';

  @override
  String get editorCancelDrawingWarning =>
      'Se descartarán los puntos sin guardar.';

  @override
  String get editorNoMapboxToken =>
      'Sin Mapbox token configurado. El mapa interactivo está desactivado; para probar el dibujo, añade un token y reinicia.';

  @override
  String get editorSegmentPath => 'Trazado';

  @override
  String get editorSegmentStartFinish => 'Inicio / meta';

  @override
  String get editorSegmentAddSector => 'Añadir sector';

  @override
  String get editorSegmentFreehand => 'A mano';

  @override
  String get editorModeFreehand => 'Dibujo a mano alzada';

  @override
  String get editorUndoFreehand => 'Deshacer trazo';

  @override
  String get editorUndoPoint => 'Deshacer punto';

  @override
  String editorPathPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puntos',
      one: '1 punto',
      zero: 'Sin puntos',
    );
    return '$_temp0';
  }

  @override
  String get editorStartGateUndefined => 'Sin inicio';

  @override
  String get editorStartGateDefined => 'Inicio definido';

  @override
  String editorSectorsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sectores',
      one: '1 sector',
      zero: 'Sin sectores',
    );
    return '$_temp0';
  }

  @override
  String get editorWaitingSecondPoint => 'Falta el 2º punto…';

  @override
  String get editorDifficultyEasy => 'Fácil';

  @override
  String get editorDifficultyMedium => 'Media';

  @override
  String get editorDifficultyHard => 'Difícil';

  @override
  String get editorHideSectors => 'Ocultar sectores';

  @override
  String get editorShowSectors => 'Ver sectores';

  @override
  String get editorNoSectorsHint => 'Sin sectores';

  @override
  String get editorClosedLoop => 'Circuito cerrado';

  @override
  String get editorOpenRoute => 'Circuito abierto';

  @override
  String editorRouteSavedSnack(String name) {
    return 'Guardada \"$name\"';
  }

  @override
  String get editorSnapFailedMessage =>
      'No se pudo conectar con el servidor para ajustar la ruta a las carreteras. Se muestran segmentos rectos hasta que la conexión se restablezca.';

  @override
  String get editorDrawingModeTooltip => 'Modo de dibujo';

  @override
  String get editorRoutingProfileTooltip => 'Modo de ruta';

  @override
  String get editorRoutingProfileDriving => 'Carretera';

  @override
  String get editorRoutingProfileWalking => 'Sendero';

  @override
  String get editorRoutingProfileCycling => 'Ciclista';

  @override
  String get editorNewRouteDialogTitle => 'Nueva ruta';

  @override
  String get editorEditRouteDialogTitle => 'Editar ruta';

  @override
  String get editorNameLabel => 'Nombre';

  @override
  String get editorDescriptionLabel => 'Descripción (opcional)';

  @override
  String get editorDifficultyLabel => 'Dificultad';

  @override
  String get editorStartDrawingButton => 'Empezar a dibujar';

  @override
  String get historyTitle => 'Rutas';

  @override
  String get historyNoSessionsTitle => 'Aún no has grabado ninguna sesión';

  @override
  String get historyNoSessionsMessage =>
      'Ve a la pestaña Sesión, elige una ruta y pulsa \"Comenzar\".';

  @override
  String get historyDeletedRoute => 'Ruta eliminada';

  @override
  String historySessionSubtitle(String date, int lapCount, String bestLap) {
    String _temp0 = intl.Intl.pluralLogic(
      lapCount,
      locale: localeName,
      other: '$lapCount vueltas',
      one: '1 vuelta',
    );
    return '$date · $_temp0$bestLap';
  }

  @override
  String get historySessionTitle => 'Sesión';

  @override
  String get historyDeleteSessionTitle => 'Eliminar sesión';

  @override
  String get historyIrreversibleWarning => 'Esta acción no se puede deshacer.';

  @override
  String get historySessionNotFound => 'Sesión no encontrada';

  @override
  String get historyLapsLabel => 'Vueltas';

  @override
  String historyLapItem(int n) {
    return 'Vuelta $n';
  }

  @override
  String get historyLapsEmpty => 'No hay vueltas registradas en esta sesión';

  @override
  String get historySectorsLabel => 'Sectores';

  @override
  String get historySectorsEmpty =>
      'No hay sectores registrados en esta sesión';

  @override
  String historySectorSubtitle(int lapNum, String speed) {
    return 'Vuelta $lapNum · $speed';
  }

  @override
  String get historyDistanceLabel => 'Distancia';

  @override
  String get historyMaxSpeedLabel => 'Vel. máx';

  @override
  String get historyAvgSpeedLabel => 'Vel. media';

  @override
  String get sessionTitle => 'Sesión en vivo';

  @override
  String get sessionNoRoutesTitle => 'No hay rutas para correr';

  @override
  String get sessionNoRoutesMessage =>
      'Crea una ruta primero en la pestaña Editor para poder grabar una sesión.';

  @override
  String get sessionSelectRoute => 'Selecciona una ruta';

  @override
  String get sessionTelemetrySource => 'Fuente de telemetría';

  @override
  String get sessionSourceSimulated => 'Simulada';

  @override
  String get sessionSourceRealGps => 'GPS real';

  @override
  String get sessionStartButton => 'Comenzar grabación';

  @override
  String get sessionConfigTitle => 'Configurar sesión';

  @override
  String get sessionConfigNameLabel => 'Nombre de la sesión (opcional)';

  @override
  String get sessionConfigNameHint => 'p. ej. Práctica de la mañana';

  @override
  String get sessionConfigIncludeHistoricalTitle =>
      'Competir contra mi mejor tiempo en esta ruta';

  @override
  String get sessionConfigIncludeHistoricalSubtitle =>
      'Si está activo, tus mejores tiempos previos por sector y vuelta en esta ruta se muestran como objetivo a batir. Si está desactivado, solo compites contra esta sesión.';

  @override
  String get sessionConfigStartButton => 'Empezar';

  @override
  String get sessionReferenceLapLabel => 'A batir';

  @override
  String get sessionSimulatedHint =>
      'Pulsa \"Simular punto\" para avanzar, o \"Auto vuelta\" para correr una vuelta automáticamente.';

  @override
  String get sessionRealGpsHint =>
      'Asegúrate de tener la ubicación activada. Los puntos se capturan cada segundo.';

  @override
  String get sessionSavedSnackBar => 'Sesión guardada';

  @override
  String get sessionNotStartedSnackBar =>
      'No se registró ninguna ruta: no cruzaste la salida';

  @override
  String get sessionFinishButton => 'Finalizar y guardar';

  @override
  String get sessionCompleteTitle => 'Sesión completa';

  @override
  String sessionRouteLabel(String routeName) {
    return 'Ruta: $routeName';
  }

  @override
  String get sessionLapsLabel => 'Vueltas';

  @override
  String get sessionNewSessionButton => 'Nueva sesión';

  @override
  String get sessionCurrentLapLabel => 'Vuelta actual';

  @override
  String sessionLapNumber(int n) {
    return '#$n';
  }

  @override
  String get sessionNoLapYet => '–';

  @override
  String get sessionLapTimeLabel => 'Tiempo en vuelta';

  @override
  String get sessionBestLapLabel => 'Mejor vuelta';

  @override
  String get sessionElapsedLabel => 'Tiempo';

  @override
  String get sessionTargetLabel => 'Objetivo';

  @override
  String get sessionFinishedOverlayTitle => 'Ruta finalizada';

  @override
  String get sessionContinueButton => 'Continuar';

  @override
  String get sessionTimeGainedLabel => 'Has ganado';

  @override
  String get sessionTimeLostLabel => 'Has perdido';

  @override
  String sessionTimeDeltaFaster(String time) {
    return '$time más rápido';
  }

  @override
  String sessionTimeDeltaSlower(String time) {
    return '$time más lento';
  }

  @override
  String get sessionAwaitingStart => 'Esperando primer cruce de meta…';

  @override
  String get sessionCrossingSectors => 'Cruzando sectores…';

  @override
  String sessionLastSector(String sectorId) {
    return 'Último sector: $sectorId';
  }

  @override
  String get sessionDistanceLabel => 'Distancia';

  @override
  String get sessionMaxSpeedLabel => 'Vel. máx.';

  @override
  String get sessionAvgSpeedLabel => 'Vel. media';

  @override
  String get sessionLapsCountLabel => 'Vueltas';

  @override
  String get sessionPermissionGranted => 'Permiso de ubicación concedido.';

  @override
  String get sessionPermissionDenied =>
      'Permiso de ubicación denegado. Acepta el diálogo del sistema o cambia a \"Simulada\".';

  @override
  String get sessionPermissionPermanentlyDenied =>
      'Permiso bloqueado permanentemente. Actívalo manualmente en los ajustes del sistema.';

  @override
  String get sessionServicesDisabled =>
      'Servicios de ubicación desactivados. Enciéndelos en los ajustes del sistema.';

  @override
  String sessionGpsStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count muestras',
      one: '1 muestra',
    );
    return 'GPS real · $_temp0';
  }

  @override
  String sessionGpsAccuracy(String accuracy, String lat, String lng) {
    return 'Precisión: $accuracy m · $lat, $lng';
  }

  @override
  String get sessionAwaitingFirstFix => 'Esperando primer fix…';

  @override
  String get gpsSignalLabel => 'Señal GPS';

  @override
  String get gpsSignalNone => 'Sin conexión';

  @override
  String get gpsSignalLow => 'Baja';

  @override
  String get gpsSignalMedium => 'Media';

  @override
  String get gpsSignalHigh => 'Alta';

  @override
  String get sessionSimulatePoint => 'Simular punto';

  @override
  String get sessionPauseAuto => 'Parar auto';

  @override
  String get sessionAutoLap => 'Auto vuelta';

  @override
  String get sessionSpeedLabel => 'Velocidad:';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsLanguageSection => 'Idioma';

  @override
  String get settingsLanguageDescription => 'Elige el idioma de la interfaz.';

  @override
  String unitMeters(String value) {
    return '$value m';
  }

  @override
  String unitKilometers(String value) {
    return '$value km';
  }

  @override
  String unitKmh(String value) {
    return '$value km/h';
  }

  @override
  String unitMph(String value) {
    return '$value mph';
  }

  @override
  String unitFeet(String value) {
    return '$value ft';
  }

  @override
  String unitMiles(String value) {
    return '$value mi';
  }

  @override
  String get settingsAppearanceSection => 'Apariencia';

  @override
  String get settingsThemeLabel => 'Tema';

  @override
  String get settingsThemeSystem => 'Seguir sistema';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsMeasurementSection => 'Medición';

  @override
  String get settingsUnitSystemLabel => 'Sistema de unidades';

  @override
  String get settingsUnitMetric => 'Métrico (km, m/s → km/h)';

  @override
  String get settingsUnitImperial => 'Imperial (mi, m/s → mph)';

  @override
  String get settingsTimeFormatLabel => 'Separador de tiempo de vuelta';

  @override
  String get settingsTimeFormatDot => 'Punto  —  01:23.456';

  @override
  String get settingsTimeFormatComma => 'Coma  —  01:23,456';

  @override
  String get settingsSessionSection => 'Comportamiento de sesión';

  @override
  String get settingsKeepScreenAwakeLabel => 'Mantener pantalla encendida';

  @override
  String get settingsKeepScreenAwakeDesc =>
      'Evita que la pantalla se apague durante una sesión activa o free ride.';

  @override
  String get settingsHapticFeedbackLabel => 'Vibración háptica';

  @override
  String get settingsHapticFeedbackDesc =>
      'Vibra al cruzar una puerta de sector o la línea de meta.';

  @override
  String get settingsAudioAlertsLabel => 'Alertas de audio';

  @override
  String get settingsAudioAlertsDesc =>
      'Reproduce un pitido corto en cada cruce de sector y vuelta.';

  @override
  String get settingsGpsSamplingLabel => 'Frecuencia GPS';

  @override
  String get settingsGpsSampling1s => 'Cada 1 s — alta precisión, más batería';

  @override
  String get settingsGpsSampling2s => 'Cada ~2 s — equilibrado';

  @override
  String get settingsGpsSampling5s => 'Cada ~5 s — menos batería';

  @override
  String get settingsRoutesSection => 'Rutas';

  @override
  String get settingsDefaultRoutingProfileLabel => 'Modo de ruta por defecto';

  @override
  String get settingsRoutingProfileRoad => 'Carretera';

  @override
  String get settingsRoutingProfileTrail => 'Sendero';

  @override
  String get settingsRoutingProfileCycling => 'Ciclismo';

  @override
  String get settingsGarageSection => 'Garaje';

  @override
  String get settingsDefaultVehicleLabel => 'Vehículo por defecto';

  @override
  String get settingsDefaultVehicleNone => 'Ninguno (preguntar siempre)';

  @override
  String get settingsAccountSection => 'Cuenta';

  @override
  String get settingsChangePasswordLabel => 'Cambiar contraseña';

  @override
  String get settingsDeleteAccountLabel => 'Eliminar cuenta';

  @override
  String get settingsDeleteAccountConfirmTitle => '¿Eliminar cuenta?';

  @override
  String get settingsDeleteAccountConfirmBody =>
      'Todos tus datos serán eliminados permanentemente. Esta acción no se puede deshacer.';

  @override
  String get settingsDeleteAccountConfirmButton => 'Eliminar mi cuenta';

  @override
  String get settingsDeleteAccountSuccess => 'Cuenta eliminada. ¡Hasta pronto!';

  @override
  String get settingsDeleteAccountError =>
      'No se pudo eliminar la cuenta. Inténtalo de nuevo.';

  @override
  String get settingsChangePasswordCurrentLabel => 'Contraseña actual';

  @override
  String get settingsChangePasswordNewLabel => 'Nueva contraseña';

  @override
  String get settingsChangePasswordConfirmLabel => 'Confirmar nueva contraseña';

  @override
  String get settingsChangePasswordButton => 'Actualizar contraseña';

  @override
  String get settingsChangePasswordSuccess => 'Contraseña actualizada';

  @override
  String get settingsChangePasswordError =>
      'No se pudo actualizar la contraseña. Inténtalo de nuevo.';

  @override
  String get settingsChangePasswordMismatch => 'Las contraseñas no coinciden';

  @override
  String get settingsChangePasswordTooShort => 'Mínimo 6 caracteres';

  @override
  String get settingsDataSection => 'Datos';

  @override
  String get settingsExportHistoryLabel => 'Exportar historial';

  @override
  String get settingsExportHistoryDesc =>
      'Descarga todas las sesiones y free rides como archivo CSV.';

  @override
  String get settingsClearCacheLabel => 'Borrar datos locales';

  @override
  String get settingsClearCacheDesc =>
      'Elimina todas las rutas y sesiones guardadas localmente. Los datos en la nube no se ven afectados.';

  @override
  String get settingsClearCacheConfirmTitle =>
      '¿Borrar todos los datos locales?';

  @override
  String get settingsClearCacheConfirmBody =>
      'Tus rutas y sesiones se eliminarán de este dispositivo. Si tienes sync activado, permanecerán en la nube.';

  @override
  String get settingsClearCacheConfirmButton => 'Borrar datos';

  @override
  String get settingsClearCacheDone => 'Datos locales borrados';

  @override
  String get settingsExportSharing => 'Exportando…';

  @override
  String get settingsDiagnosticsSection => 'Diagnóstico';

  @override
  String get settingsDiagnosticsLogsLabel => 'Ver logs';

  @override
  String get settingsDiagnosticsLogsDesc =>
      'Errores y advertencias de Mapbox, Supabase y la app';

  @override
  String get settingsDiagnosticsRemoteLogsLabel => 'Subir logs al servidor';

  @override
  String get settingsDiagnosticsRemoteLogsDesc =>
      'Permite revisar los logs desde el dashboard de Supabase';

  @override
  String get logsScreenTitle => 'Diagnóstico';

  @override
  String get logsUploadTooltip => 'Subir ahora';

  @override
  String get logsShareTooltip => 'Compartir todo';

  @override
  String get logsClearTooltip => 'Borrar todo';

  @override
  String get logsClearConfirmTitle => '¿Borrar todos los logs?';

  @override
  String get logsClearConfirmBody => 'Esta acción no se puede deshacer.';

  @override
  String get logsClearConfirmButton => 'Borrar';

  @override
  String logsPending(int count) {
    return '$count pendientes de subir';
  }

  @override
  String get logsEmpty => 'No hay logs todavía';

  @override
  String get logsSearchHint => 'Buscar…';

  @override
  String get logsCopiedToClipboard => 'Copiado al portapapeles';

  @override
  String get mapNoRoute => 'Sin ruta';

  @override
  String historyBestLapSuffix(String duration) {
    return ' · mejor $duration';
  }

  @override
  String get navFreeRide => 'Sin destino';

  @override
  String get freeRideTitle => 'Sin destino';

  @override
  String get freeRideIdleTitle => 'Ruta sin destino';

  @override
  String get freeRideIdleMessage =>
      'Graba tu recorrido en tiempo real sin una ruta predefinida. Se registran velocidad, distancia y posición automáticamente.';

  @override
  String get freeRideStartButton => 'Comenzar grabación';

  @override
  String get freeRideSetupTitle => 'Nueva grabación';

  @override
  String get freeRideSetupNameLabel => 'Nombre (opcional)';

  @override
  String get freeRideElapsedLabel => 'Tiempo';

  @override
  String get freeRideDistanceLabel => 'Distancia';

  @override
  String get freeRideSpeedLabel => 'Velocidad';

  @override
  String get freeRideMaxSpeedLabel => 'Vel. máx.';

  @override
  String get freeRideAvgSpeedLabel => 'Vel. media';

  @override
  String get freeRideFinishButton => 'Finalizar recorrido';

  @override
  String get freeRideCompleteTitle => 'Recorrido completo';

  @override
  String get freeRideSavedSnackBar => 'Recorrido guardado';

  @override
  String get freeRideSaveAsRouteButton => 'Guardar como ruta reutilizable';

  @override
  String get freeRideDiscardButton => 'Finalizar sin guardar ruta';

  @override
  String get freeRideNewRideButton => 'Nuevo recorrido';

  @override
  String get freeRideSaveRouteDialogTitle => 'Guardar como ruta';

  @override
  String get freeRideNameLabel => 'Nombre';

  @override
  String get freeRideDescriptionLabel => 'Descripción (opcional)';

  @override
  String get freeRideDifficultyLabel => 'Dificultad';

  @override
  String freeRideRouteSavedSnack(String name) {
    return 'Ruta \"$name\" guardada';
  }

  @override
  String freeRidePointsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puntos',
      one: '1 punto',
    );
    return '$_temp0';
  }

  @override
  String get historyNoEntriesTitle => 'Aún no hay actividad';

  @override
  String get historyNoEntriesMessage =>
      'Haz un recorrido libre o graba una sesión en una ruta.';

  @override
  String get historyFreeRideLabel => 'Recorrido libre';

  @override
  String historyFreeRideSubtitle(String date, String distance) {
    return '$date · $distance';
  }

  @override
  String get historyDeleteFreeRideTitle => 'Eliminar recorrido libre';

  @override
  String get historyFreeRideTitle => 'Detalle del recorrido';

  @override
  String get historyRenameFreeRideTitle => 'Renombrar recorrido';

  @override
  String get historyRenameFreeRideLabel => 'Nombre';

  @override
  String get historyRenamedSnack => 'Nombre actualizado';

  @override
  String get historyRenameRouteTitle => 'Renombrar ruta';

  @override
  String get historyRenameRouteLabel => 'Nombre';

  @override
  String get historySearchHint => 'Buscar…';

  @override
  String get historyFiltersTitle => 'Filtros';

  @override
  String get historyFiltersOpen => 'Abrir filtros';

  @override
  String get historyFiltersApply => 'Aplicar';

  @override
  String get historyFiltersClear => 'Limpiar';

  @override
  String get historyFilterKindLabel => 'Tipo';

  @override
  String get historyFilterKindSession => 'Sesión';

  @override
  String get historyFilterKindFreeRide => 'Free ride';

  @override
  String get historyFilterVehicleLabel => 'Vehículo';

  @override
  String get historyNoVehicle => 'Sin vehículo';

  @override
  String get historyFilterDateRangeLabel => 'Rango de fechas';

  @override
  String get historyDateLast7Days => 'Últimos 7 días';

  @override
  String get historyDateLast30Days => 'Últimos 30 días';

  @override
  String get historyDateThisYear => 'Este año';

  @override
  String get historyDateCustom => 'Personalizado';

  @override
  String get historyFilterMinDistanceLabel => 'Distancia mínima';

  @override
  String historyFilterMinDistanceChip(String value) {
    return '≥ $value';
  }

  @override
  String historyFilterVehicleChipMany(int count) {
    return 'Vehículos ($count)';
  }

  @override
  String get historyFilteredEmptyTitle => 'Sin resultados';

  @override
  String get historyFilteredEmptyAction => 'Limpiar filtros';

  @override
  String get historyFilterGroupByRoute => 'Agrupar por ruta';

  @override
  String get historyGroupFreeRides => 'Rutas libres';

  @override
  String get historyGroupChip => 'Agrupado por ruta';

  @override
  String historyGroupSubtitle(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesiones',
      one: '1 sesión',
    );
    return '$_temp0 · última $date';
  }

  @override
  String get routesTitle => 'Mis rutas';

  @override
  String get routesViewList => 'Lista';

  @override
  String get routesViewGrid => 'Mosaico';

  @override
  String routesSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesiones',
      one: '1 sesión',
      zero: 'Sin sesiones',
    );
    return '$_temp0';
  }

  @override
  String routesBestLap(String time) {
    return 'Mejor: $time';
  }

  @override
  String get routesDetailTitle => 'Detalle de ruta';

  @override
  String get navGarage => 'Garaje';

  @override
  String get garageTitle => 'Mi garaje';

  @override
  String get garageNoVehiclesTitle => 'No hay vehículos';

  @override
  String get garageNoVehiclesMessage =>
      'Añade tu primer coche, moto o kart para registrar con qué vehículo corres cada sesión.';

  @override
  String get garageAddVehicleButton => 'Añadir vehículo';

  @override
  String get garageViewList => 'Lista';

  @override
  String get garageViewGrid => 'Mosaico';

  @override
  String get garageDeleteVehicleTitle => 'Eliminar vehículo';

  @override
  String garageDeleteVehicleConfirm(String vehicleName) {
    return '¿Eliminar \"$vehicleName\"? Esta acción no se puede deshacer.';
  }

  @override
  String get garageVehicleSavedSnack => 'Vehículo guardado';

  @override
  String get garageVehicleDeletedSnack => 'Vehículo eliminado';

  @override
  String get garagePhotoUpdated => 'Foto actualizada';

  @override
  String get garageErrorUnexpected => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get garageChangePhoto => 'Cambiar foto';

  @override
  String get vehicleFormTitleNew => 'Nuevo vehículo';

  @override
  String get vehicleFormTitleEdit => 'Editar vehículo';

  @override
  String get vehicleFormNameLabel => 'Nombre';

  @override
  String get vehicleFormNameRequired => 'Introduce un nombre';

  @override
  String get vehicleFormNameMinLength => 'Mínimo 2 caracteres';

  @override
  String get vehicleFormTypeLabel => 'Tipo';

  @override
  String get vehicleFormModelLabel => 'Modelo (opcional)';

  @override
  String get vehicleFormYearLabel => 'Año (opcional)';

  @override
  String get vehicleFormHorsepowerLabel => 'Caballos (opcional)';

  @override
  String get vehicleFormTorqueLabel => 'Par motor Nm (opcional)';

  @override
  String get vehicleFormWeightLabel => 'Peso kg (opcional)';

  @override
  String get vehicleFormDrivetrainLabel => 'Tracción (opcional)';

  @override
  String get vehicleFormNotesLabel => 'Notas (opcional)';

  @override
  String get vehicleFormNotesHint => 'Neumáticos, modificaciones, etc.';

  @override
  String get vehicleFormSaveButton => 'Guardar';

  @override
  String get vehicleTypeCar => 'Coche';

  @override
  String get vehicleTypeMotorcycle => 'Moto';

  @override
  String get vehicleTypeBicycle => 'Bicicleta';

  @override
  String get vehicleTypeGoKart => 'Kart';

  @override
  String get vehicleTypeOther => 'Otro';

  @override
  String get drivetrainFront => 'Tracción delantera';

  @override
  String get drivetrainRear => 'Tracción trasera';

  @override
  String get drivetrainAllWheel => 'Tracción total';

  @override
  String get vehicleDetailSpecs => 'Especificaciones';

  @override
  String vehicleDetailHorsepower(int hp) {
    return '$hp cv';
  }

  @override
  String vehicleDetailTorque(int nm) {
    return '$nm Nm';
  }

  @override
  String vehicleDetailWeight(int kg) {
    return '$kg kg';
  }

  @override
  String get vehiclePickerLabel => 'Vehículo';

  @override
  String get vehiclePickerOnFoot => 'A pie';

  @override
  String get vehiclePickerSelectVehicle => 'Selecciona un vehículo';

  @override
  String get elevationRangeLabel => 'Desnivel';

  @override
  String get routeExpectedTimeLabel => 'Tiempo normal';

  @override
  String elevationRangeValue(String value) {
    return '$value m';
  }

  @override
  String elevationRangeValueFeet(String value) {
    return '$value ft';
  }

  @override
  String get backgroundNotificationTitle => 'Splitway · Grabando ruta';

  @override
  String get backgroundDeniedBanner =>
      'La grabación se detendrá si sales de la app. Concede permiso \"Siempre\" para grabar en segundo plano.';

  @override
  String get backgroundOpenSettings => 'Abrir ajustes';

  @override
  String get backgroundDialogTitle => 'Grabación en segundo plano';

  @override
  String get backgroundDialogBody =>
      'Para que la ruta siga grabándose con la pantalla apagada o al cambiar de app, necesitas permitir el acceso a la ubicación \"Siempre\".\n\nVe a Ajustes > Permisos > Ubicación y selecciona \"Permitir siempre\".';

  @override
  String get backgroundDialogOpenSettings => 'Abrir ajustes';

  @override
  String get backgroundDialogSkip => 'Continuar sin segundo plano';

  @override
  String get notificationDialogTitle => 'Activar notificaciones';

  @override
  String get notificationDialogBody =>
      'Splitway usa notificaciones para mantenerte informado durante la grabación de rutas: tiempo transcurrido, distancia y estado del seguimiento, incluso con la app en segundo plano.';

  @override
  String get notificationDialogAllow => 'Permitir notificaciones';

  @override
  String get notificationDialogSkip => 'Ahora no';

  @override
  String get mapStyleOutdoors => 'Exterior';

  @override
  String get mapStyleSatelliteStreets => 'Satélite';

  @override
  String get mapStyleDark => 'Oscuro';

  @override
  String get mapStyleLayersTooltip => 'Estilo del mapa';

  @override
  String get heatmapToggleOn => 'Mostrar mapa de calor';

  @override
  String get heatmapToggleOff => 'Ocultar mapa de calor';

  @override
  String get heatmapLegendTitle => 'Velocidad';

  @override
  String get editorSearchLocationHint => 'Buscar ubicación...';

  @override
  String get editorSearchNoResults => 'Sin resultados';

  @override
  String get navSpeed => 'Test de velocidad';

  @override
  String get drawerSpeed => 'Test de velocidad';

  @override
  String get speedSetupTitle => 'Test de velocidad';

  @override
  String get speedSetupVehicleSection => 'Vehículo';

  @override
  String get speedSetupVehicleEmpty => 'Aún no tienes vehículos en tu garaje';

  @override
  String get speedSetupMetricsSection => 'Qué medir';

  @override
  String get speedSetupCountdownSection => 'Cuenta atrás';

  @override
  String get speedSetupNameSection => 'Nombre (opcional)';

  @override
  String get speedSetupNameHint => 'Deja vacío para el nombre por defecto';

  @override
  String get speedSetupViewSection => 'Vista de resultados';

  @override
  String get speedSetupViewList => 'Lista';

  @override
  String get speedSetupViewGrid => 'Cuadrícula';

  @override
  String get speedSetupContinue => 'Continuar';

  @override
  String speedSetupSecondsValue(int n) {
    return '${n}s';
  }

  @override
  String get speedReadyMessage => 'Cuando estés listo, pulsa Start';

  @override
  String get speedReadyStart => 'START';

  @override
  String get speedSessionGo => '¡YA!';

  @override
  String get speedFinishedTitle => 'Sesión completada';

  @override
  String get speedFinishedSave => 'Guardar';

  @override
  String get speedFinishedDiscard => 'Descartar';

  @override
  String get speedFinishedManualStop => 'Parar';

  @override
  String get speedFalseStartTitle => 'SALIDA EN FALSO';

  @override
  String get speedFalseStartSubtitle => 'Has arrancado antes del pitido final';

  @override
  String get speedFalseStartRetry => 'REINTENTAR';

  @override
  String get speedFalseStartCancel => 'Cancelar';

  @override
  String get speedCategoryDrag => 'Drag';

  @override
  String get speedCategoryStopwatch => 'Cronómetro';

  @override
  String get speedCategoryOther => 'Otros';

  @override
  String get speedMetricReactionTime => 'Tiempo de reacción';

  @override
  String get speedMetricSixtyFoot => '60 pies';

  @override
  String get speedMetricEighthMile => '1/8 milla';

  @override
  String get speedMetricQuarterMile => '1/4 milla';

  @override
  String get speedMetricZeroTo50 => '0-50';

  @override
  String get speedMetricZeroTo100 => '0-100';

  @override
  String get speedMetricZeroTo200 => '0-200';

  @override
  String get speedMetricTopSpeed => 'Velocidad máxima';

  @override
  String get speedHistoryTab => 'Test de velocidad';

  @override
  String get speedHistoryEmpty => 'Aún no hay sesiones de velocidad';

  @override
  String get speedHistoryDeleteTooltip => 'Eliminar';

  @override
  String get speedHistoryDeleteTitle => 'Eliminar sesión';

  @override
  String speedHistoryDeleteConfirm(String name) {
    return '¿Eliminar \"$name\"? Esta acción no se puede deshacer.';
  }

  @override
  String get speedDetailEditNameTooltip => 'Editar nombre';

  @override
  String get speedDetailEditNameTitle => 'Editar nombre';

  @override
  String get speedDetailEditNameHint => 'Nombre de la sesión';

  @override
  String get speedDetailEditNameSave => 'Guardar';

  @override
  String get speedDetailEditNameCancel => 'Cancelar';

  @override
  String get speedDetailEditNameError => 'No se pudo guardar el nombre';

  @override
  String get statsTitle => 'Estadísticas';

  @override
  String get statsEmptyTitle => 'Aún no hay datos';

  @override
  String get statsEmptyMessage =>
      'Registra una sesión, un free ride o un test de velocidad para ver tus estadísticas aquí.';

  @override
  String get statsOverviewSection => 'Resumen';

  @override
  String get statsTotalSessions => 'Actividades totales';

  @override
  String get statsTotalDistance => 'Distancia total';

  @override
  String get statsTotalTime => 'Tiempo total';

  @override
  String get statsVehiclesOwned => 'Vehículos';

  @override
  String get statsPersonalBestsSection => 'Récords personales';

  @override
  String get statsRecordsSection => 'Récords';

  @override
  String get statsTopSpeedRecord => 'Velocidad máxima';

  @override
  String get statsLongestRide => 'Ride más largo';

  @override
  String get statsLongestSession => 'Sesión más larga';

  @override
  String get statsActivitySection => 'Últimas 8 semanas';

  @override
  String get statsActivityWeekly => 'Actividades por semana';

  @override
  String get statsByVehicleSection => 'Por vehículo';

  @override
  String get statsNoBestYet => '—';

  @override
  String statsActivitiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actividades',
      one: '1 actividad',
      zero: 'Sin actividades',
    );
    return '$_temp0';
  }

  @override
  String get statsBestQuarterMileShort => 'Mejor 1/4 mi';

  @override
  String get statsNoSpeedSessionsForVehicle => 'Sin tests';

  @override
  String get statsUnknownVehicle => 'Vehículo desconocido';

  @override
  String get statsMetricSelectorLabel => 'Métrica:';

  @override
  String get recordingPauseButton => 'Pausar recorrido';

  @override
  String get recordingResumeButton => 'Reanudar';
}
