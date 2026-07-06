// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Splitway';

  @override
  String get appTagline => 'Smart stopwatch for routes';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSave => 'Save';

  @override
  String get commonClose => 'Got it';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonDiscard => 'Discard';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get navEditor => 'Editor';

  @override
  String get navSession => 'Session';

  @override
  String get navHistory => 'History';

  @override
  String get navRoutes => 'Routes';

  @override
  String get drawerMenu => 'Menu';

  @override
  String get drawerDefaultUser => 'User';

  @override
  String get drawerSettings => 'Settings';

  @override
  String get drawerStats => 'Statistics';

  @override
  String get drawerHelp => 'Help';

  @override
  String get drawerSignOut => 'Sign out';

  @override
  String get drawerSignIn => 'Sign in';

  @override
  String drawerAppVersion(String version) {
    return 'v$version';
  }

  @override
  String get drawerSyncSynced => 'SYNCED';

  @override
  String get drawerSyncSyncedNow => 'SYNCED · now';

  @override
  String drawerSyncSyncedMinutes(int minutes) {
    return 'SYNCED · $minutes min ago';
  }

  @override
  String drawerSyncSyncedAt(String time) {
    return 'SYNCED · $time';
  }

  @override
  String get drawerSyncSyncing => 'SYNCING…';

  @override
  String get drawerSyncError => 'SYNC ERROR';

  @override
  String get drawerSyncOffline => 'OFFLINE';

  @override
  String get drawerSyncPending => 'PENDING CHANGES';

  @override
  String get drawerProfile => 'Profile';

  @override
  String get loginBannerDefault => 'Sign in to continue';

  @override
  String get loginEmailHint => 'Email';

  @override
  String get loginPasswordHint => 'Password';

  @override
  String get loginEmailRequired => 'Enter an email';

  @override
  String get loginEmailInvalid => 'Invalid email';

  @override
  String get loginPasswordRequired => 'Enter a password';

  @override
  String get loginPasswordMinLength => 'Minimum 6 characters';

  @override
  String get loginConfirmPasswordHint => 'Confirm password';

  @override
  String get loginPasswordMismatch => 'Passwords do not match';

  @override
  String get loginSignInButton => 'Sign in';

  @override
  String get loginSignUpButton => 'Create account';

  @override
  String get loginOrSeparator => '— or —';

  @override
  String get loginContinueWithGoogle => 'Continue with Google';

  @override
  String get loginToggleToSignUp => 'Don\'t have an account? ';

  @override
  String get loginToggleToSignIn => 'Already have an account? ';

  @override
  String get loginToggleSignUpAction => 'Sign up';

  @override
  String get loginToggleSignInAction => 'Sign in';

  @override
  String get loginSkipButton => 'Continue without account';

  @override
  String get loginNicknameHint => 'Nickname';

  @override
  String get loginNicknameRequired => 'Enter a nickname';

  @override
  String get loginNicknameMinLength => 'Minimum 2 characters';

  @override
  String get loginConfirmationTitle => 'Check your inbox!';

  @override
  String loginConfirmationBody(String email) {
    return 'We sent a confirmation link to\n$email\n\nClick the link to activate your account and sign in.';
  }

  @override
  String get authErrorGoogleToken => 'Could not retrieve Google token.';

  @override
  String get authErrorEmailAlreadyRegistered =>
      'This email is already registered. Sign in.';

  @override
  String get authErrorInvalidCredentials => 'Wrong email or password.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Confirm your email before signing in.';

  @override
  String get authErrorPasswordTooShort =>
      'Password must be at least 6 characters.';

  @override
  String get authErrorNoConnection => 'No connection. Try again.';

  @override
  String get authErrorUnexpected => 'Unexpected error. Try again.';

  @override
  String get authErrorBanned => 'Your account is banned.';

  @override
  String authErrorBannedUntil(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Your account is banned until $dateString.';
  }

  @override
  String get loginForgotPassword => 'Forgot your password?';

  @override
  String get loginForgotPasswordTitle => 'Reset password';

  @override
  String get loginForgotPasswordBody =>
      'Enter your email and we\'ll send you a link to reset your password.';

  @override
  String get loginForgotPasswordButton => 'Send reset link';

  @override
  String loginForgotPasswordSuccess(String email) {
    return 'We sent a reset link to $email. Check your inbox.';
  }

  @override
  String get loginForgotPasswordError =>
      'Could not send reset email. Try again.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileAvatarUpdated => 'Avatar updated';

  @override
  String get profileErrorUnexpected => 'Could not update avatar. Try again.';

  @override
  String get profileNicknameUpdated => 'Nickname updated';

  @override
  String get profileErrorCooldown =>
      'Nickname can only be changed after the cooldown.';

  @override
  String get profileBioUpdated => 'Bio updated';

  @override
  String get profileChangeAvatar => 'Change avatar';

  @override
  String get profileNicknameLabel => 'Nickname';

  @override
  String get profileNicknameRequired => 'Enter a nickname';

  @override
  String get profileNicknameMinLength => 'Minimum 2 characters';

  @override
  String get profileNicknameTooLong => 'Maximum 30 characters';

  @override
  String get profileBioLabel => 'Bio';

  @override
  String get profileBioHint => 'Tell others a little bit about yourself';

  @override
  String profileNicknameCooldownDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String profileNicknameCooldownHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String get profileNicknameCooldown => 'Nickname change available in';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profileDateOfBirthLabel => 'Date of birth';

  @override
  String get loginDateOfBirthHint => 'Date of birth';

  @override
  String get onboardingTitle => 'Complete your profile';

  @override
  String get onboardingDescription =>
      'We need a few things to finish setting up your account. The password will let you sign in with email too.';

  @override
  String get onboardingSubmit => 'Save and continue';

  @override
  String get onboardingSubmitLoading => 'Saving…';

  @override
  String get onboardingDobInvalid => 'You must be at least 13 years old.';

  @override
  String get onboardingProfileFailed =>
      'Could not save the profile. Please try again.';

  @override
  String get onboardingPasswordFailed => 'Could not set the password.';

  @override
  String get onboardingPasswordMinLength => 'Minimum 8 characters.';

  @override
  String get editorTitle => 'Route editor';

  @override
  String get editorNewRouteTooltip => 'New route';

  @override
  String get editorNewRouteButton => 'New route';

  @override
  String get editorNoRoutesTitle => 'No routes yet';

  @override
  String get editorNoRoutesMessage =>
      'Create your first route to start timing.';

  @override
  String get editorSectorsLabel => 'Sectors';

  @override
  String editorSectorCenter(String lat, String lng) {
    return 'Center: $lat, $lng';
  }

  @override
  String get editorStartFinishLabel => 'Start / finish';

  @override
  String editorCreatedAt(String date) {
    return 'Created on $date';
  }

  @override
  String get editorDeleteRouteButton => 'Delete route';

  @override
  String get editorDeleteRouteTitle => 'Delete route';

  @override
  String editorDeleteRouteConfirm(String routeName) {
    return 'Delete \"$routeName\" and all its sessions?';
  }

  @override
  String get editorModeAppendPath => 'Append path';

  @override
  String get editorModeStartGate => 'Start/finish';

  @override
  String get editorModeSectorGate => 'Sector gate';

  @override
  String editorDrawingTitle(String draftName) {
    return 'Drawing: $draftName';
  }

  @override
  String get editorCancelTooltip => 'Cancel';

  @override
  String get editorCancelDrawingTitle => 'Cancel drawing';

  @override
  String get editorCancelDrawingWarning => 'Unsaved points will be discarded.';

  @override
  String get editorNoMapboxToken =>
      'Mapbox token not configured. The interactive map is disabled; add a token and restart to draw.';

  @override
  String get editorSegmentPath => 'Path';

  @override
  String get editorSegmentStartFinish => 'Start / finish';

  @override
  String get editorSegmentAddSector => 'Add sector';

  @override
  String get editorSegmentFreehand => 'Freehand';

  @override
  String get editorModeFreehand => 'Draw freehand';

  @override
  String get editorUndoFreehand => 'Undo stroke';

  @override
  String get editorUndoPoint => 'Undo point';

  @override
  String editorPathPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
      zero: 'No points',
    );
    return '$_temp0';
  }

  @override
  String get editorStartGateUndefined => 'No start';

  @override
  String get editorStartGateDefined => 'Start defined';

  @override
  String editorSectorsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sectors',
      one: '1 sector',
      zero: 'No sectors',
    );
    return '$_temp0';
  }

  @override
  String get editorWaitingSecondPoint => 'Waiting for 2nd point…';

  @override
  String get editorDifficultyEasy => 'Easy';

  @override
  String get editorDifficultyMedium => 'Medium';

  @override
  String get editorDifficultyHard => 'Hard';

  @override
  String get editorHideSectors => 'Hide sectors';

  @override
  String get editorShowSectors => 'Show sectors';

  @override
  String get editorNoSectorsHint => 'No sectors';

  @override
  String get editorClosedLoop => 'Closed loop';

  @override
  String get editorOpenRoute => 'Open route';

  @override
  String editorRouteSavedSnack(String name) {
    return 'Saved \"$name\"';
  }

  @override
  String get editorSnapFailedMessage =>
      'Could not reach the server to snap the route to roads. Showing straight segments until the connection is restored.';

  @override
  String get editorDrawingModeTooltip => 'Drawing mode';

  @override
  String get editorRoutingProfileTooltip => 'Routing mode';

  @override
  String get editorRoutingProfileDriving => 'Road';

  @override
  String get editorRoutingProfileWalking => 'Trail';

  @override
  String get editorRoutingProfileCycling => 'Cycling';

  @override
  String get editorNewRouteDialogTitle => 'New route';

  @override
  String get editorEditRouteDialogTitle => 'Edit route';

  @override
  String get editorNameLabel => 'Name';

  @override
  String get editorDescriptionLabel => 'Description (optional)';

  @override
  String get editorDifficultyLabel => 'Difficulty';

  @override
  String get editorStartDrawingButton => 'Start drawing';

  @override
  String get historyTitle => 'Sessions';

  @override
  String get historyNoSessionsTitle => 'No sessions recorded yet';

  @override
  String get historyNoSessionsMessage =>
      'Go to the Session tab, pick a route, and tap \"Start\".';

  @override
  String get historyDeletedRoute => 'Deleted route';

  @override
  String historySessionSubtitle(String date, int lapCount, String bestLap) {
    String _temp0 = intl.Intl.pluralLogic(
      lapCount,
      locale: localeName,
      other: '$lapCount laps',
      one: '1 lap',
    );
    return '$date · $_temp0$bestLap';
  }

  @override
  String get historySessionTitle => 'Session';

  @override
  String get historyDeleteSessionTitle => 'Delete session';

  @override
  String get historyIrreversibleWarning => 'This action cannot be undone.';

  @override
  String get historySessionNotFound => 'Session not found';

  @override
  String get historyLapsLabel => 'Laps';

  @override
  String historyLapItem(int n) {
    return 'Lap $n';
  }

  @override
  String get historyLapsEmpty => 'No laps recorded in this session';

  @override
  String get historySectorsLabel => 'Sectors';

  @override
  String get historySectorsEmpty => 'No sectors recorded in this session';

  @override
  String historySectorSubtitle(int lapNum, String speed) {
    return 'Lap $lapNum · $speed';
  }

  @override
  String get historyDistanceLabel => 'Distance';

  @override
  String get historyMaxSpeedLabel => 'Max speed';

  @override
  String get historyAvgSpeedLabel => 'Avg speed';

  @override
  String get sessionTitle => 'Live session';

  @override
  String get sessionNoRoutesTitle => 'No routes to run';

  @override
  String get sessionNoRoutesMessage =>
      'Create a route in the Editor tab first to record a session.';

  @override
  String get sessionSelectRoute => 'Select a route';

  @override
  String get sessionTelemetrySource => 'Telemetry source';

  @override
  String get sessionSourceSimulated => 'Simulated';

  @override
  String get sessionSourceRealGps => 'Real GPS';

  @override
  String get sessionStartButton => 'Start recording';

  @override
  String get sessionConfigTitle => 'Session setup';

  @override
  String get sessionConfigNameLabel => 'Session name (optional)';

  @override
  String get sessionConfigNameHint => 'e.g. Morning practice';

  @override
  String get sessionConfigIncludeHistoricalTitle =>
      'Compete against my best on this route';

  @override
  String get sessionConfigIncludeHistoricalSubtitle =>
      'When on, your best previous sector and lap times on this route are shown as the target to beat. When off, you only compete against this session.';

  @override
  String get sessionConfigStartButton => 'Start';

  @override
  String get sessionReferenceLapLabel => 'To beat';

  @override
  String get sessionSimulatedHint =>
      'Tap \"Simulate point\" to advance, or \"Auto lap\" to run a lap automatically.';

  @override
  String get sessionRealGpsHint =>
      'Make sure location is enabled. Points are captured every second.';

  @override
  String get sessionSavedSnackBar => 'Session saved';

  @override
  String get sessionNotStartedSnackBar =>
      'No route recorded — you didn\'t cross the start line';

  @override
  String get sessionFinishButton => 'Finish and save';

  @override
  String get sessionCompleteTitle => 'Session complete';

  @override
  String sessionRouteLabel(String routeName) {
    return 'Route: $routeName';
  }

  @override
  String get sessionLapsLabel => 'Laps';

  @override
  String get sessionNewSessionButton => 'New session';

  @override
  String get sessionCurrentLapLabel => 'Current lap';

  @override
  String sessionLapNumber(int n) {
    return '#$n';
  }

  @override
  String get sessionNoLapYet => '–';

  @override
  String get sessionLapTimeLabel => 'Lap time';

  @override
  String get sessionBestLapLabel => 'Best lap';

  @override
  String get sessionElapsedLabel => 'Time';

  @override
  String get sessionTargetLabel => 'Target';

  @override
  String get sessionFinishedOverlayTitle => 'Route finished';

  @override
  String get sessionContinueButton => 'Continue';

  @override
  String get sessionTimeGainedLabel => 'You gained';

  @override
  String get sessionTimeLostLabel => 'You lost';

  @override
  String sessionTimeDeltaFaster(String time) {
    return '$time faster';
  }

  @override
  String sessionTimeDeltaSlower(String time) {
    return '$time slower';
  }

  @override
  String get sessionAwaitingStart => 'Waiting for first finish-line crossing…';

  @override
  String get sessionCrossingSectors => 'Crossing sectors…';

  @override
  String sessionLastSector(String sectorId) {
    return 'Last sector: $sectorId';
  }

  @override
  String get sessionDistanceLabel => 'Distance';

  @override
  String get sessionMaxSpeedLabel => 'Max speed';

  @override
  String get sessionAvgSpeedLabel => 'Avg speed';

  @override
  String get sessionLapsCountLabel => 'Laps';

  @override
  String get sessionPermissionGranted => 'Location permission granted.';

  @override
  String get sessionPermissionDenied =>
      'Location permission denied. Accept the system dialog or switch to \"Simulated\".';

  @override
  String get sessionPermissionPermanentlyDenied =>
      'Permission permanently blocked. Enable it manually in system settings.';

  @override
  String get sessionServicesDisabled =>
      'Location services disabled. Turn them on in system settings.';

  @override
  String sessionGpsStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samples',
      one: '1 sample',
    );
    return 'Real GPS · $_temp0';
  }

  @override
  String sessionGpsAccuracy(String accuracy, String lat, String lng) {
    return 'Accuracy: $accuracy m · $lat, $lng';
  }

  @override
  String get sessionAwaitingFirstFix => 'Waiting for first fix…';

  @override
  String get gpsSignalLabel => 'GPS Signal';

  @override
  String get gpsSignalNone => 'No signal';

  @override
  String get gpsSignalLow => 'Low';

  @override
  String get gpsSignalMedium => 'Medium';

  @override
  String get gpsSignalHigh => 'High';

  @override
  String get sessionSimulatePoint => 'Simulate point';

  @override
  String get sessionPauseAuto => 'Pause auto';

  @override
  String get sessionAutoLap => 'Auto lap';

  @override
  String get sessionSpeedLabel => 'Speed:';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsLanguageDescription => 'Choose the app display language.';

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
  String get settingsAppearanceSection => 'Appearance';

  @override
  String get settingsThemeLabel => 'Theme';

  @override
  String get settingsThemeSystem => 'System default';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsMeasurementSection => 'Measurement';

  @override
  String get settingsUnitSystemLabel => 'Unit system';

  @override
  String get settingsUnitMetric => 'Metric (km, m/s → km/h)';

  @override
  String get settingsUnitImperial => 'Imperial (mi, m/s → mph)';

  @override
  String get settingsTimeFormatLabel => 'Lap time separator';

  @override
  String get settingsTimeFormatDot => 'Dot  —  01:23.456';

  @override
  String get settingsTimeFormatComma => 'Comma  —  01:23,456';

  @override
  String get settingsSessionSection => 'Session behaviour';

  @override
  String get settingsKeepScreenAwakeLabel => 'Keep screen awake';

  @override
  String get settingsKeepScreenAwakeDesc =>
      'Prevents the display from sleeping during an active session or free ride.';

  @override
  String get settingsHapticFeedbackLabel => 'Haptic feedback';

  @override
  String get settingsHapticFeedbackDesc =>
      'Vibrate when crossing a sector gate or the finish line.';

  @override
  String get settingsAudioAlertsLabel => 'Audio alerts';

  @override
  String get settingsAudioAlertsDesc =>
      'Play a short beep on each sector and lap crossing.';

  @override
  String get settingsGpsSamplingLabel => 'GPS update rate';

  @override
  String get settingsGpsSampling1s => 'Every 1 s — high accuracy, more battery';

  @override
  String get settingsGpsSampling2s => 'Every ~2 s — balanced';

  @override
  String get settingsGpsSampling5s => 'Every ~5 s — low battery';

  @override
  String get settingsRoutesSection => 'Routes';

  @override
  String get settingsDefaultRoutingProfileLabel => 'Default routing mode';

  @override
  String get settingsRoutingProfileRoad => 'Road';

  @override
  String get settingsRoutingProfileTrail => 'Trail';

  @override
  String get settingsRoutingProfileCycling => 'Cycling';

  @override
  String get settingsGarageSection => 'Garage';

  @override
  String get settingsDefaultVehicleLabel => 'Default vehicle';

  @override
  String get settingsDefaultVehicleNone => 'None (always ask)';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsChangePasswordLabel => 'Change password';

  @override
  String get settingsDeleteAccountLabel => 'Delete account';

  @override
  String get settingsDeleteAccountConfirmTitle => 'Delete account?';

  @override
  String get settingsDeleteAccountConfirmBody =>
      'All your data will be permanently deleted. This cannot be undone.';

  @override
  String get settingsDeleteAccountConfirmButton => 'Delete my account';

  @override
  String get settingsDeleteAccountSuccess => 'Account deleted. Goodbye!';

  @override
  String get settingsDeleteAccountError =>
      'Could not delete account. Try again.';

  @override
  String get settingsChangePasswordCurrentLabel => 'Current password';

  @override
  String get settingsChangePasswordNewLabel => 'New password';

  @override
  String get settingsChangePasswordConfirmLabel => 'Confirm new password';

  @override
  String get settingsChangePasswordButton => 'Update password';

  @override
  String get settingsChangePasswordSuccess => 'Password updated';

  @override
  String get settingsChangePasswordError =>
      'Could not update password. Try again.';

  @override
  String get settingsChangePasswordMismatch => 'Passwords do not match';

  @override
  String get settingsChangePasswordTooShort => 'Minimum 6 characters';

  @override
  String get settingsDataSection => 'Data';

  @override
  String get settingsExportHistoryLabel => 'Export history';

  @override
  String get settingsExportHistoryDesc =>
      'Download all sessions and free rides as a CSV file.';

  @override
  String get settingsClearCacheLabel => 'Clear local data';

  @override
  String get settingsClearCacheDesc =>
      'Deletes all locally saved routes and sessions. Cloud data is not affected.';

  @override
  String get settingsClearCacheConfirmTitle => 'Clear all local data?';

  @override
  String get settingsClearCacheConfirmBody =>
      'Your routes and sessions will be deleted from this device. If sync is enabled they will remain in the cloud.';

  @override
  String get settingsClearCacheConfirmButton => 'Clear data';

  @override
  String get settingsClearCacheDone => 'Local data cleared';

  @override
  String get settingsExportSharing => 'Exporting…';

  @override
  String get settingsDiagnosticsSection => 'Diagnostics';

  @override
  String get settingsDiagnosticsLogsLabel => 'View logs';

  @override
  String get settingsDiagnosticsLogsDesc =>
      'Errors and warnings from Mapbox, Supabase and the app';

  @override
  String get settingsDiagnosticsRemoteLogsLabel => 'Upload logs to server';

  @override
  String get settingsDiagnosticsRemoteLogsDesc =>
      'Allows reviewing logs from the Supabase dashboard';

  @override
  String get logsScreenTitle => 'Diagnostics';

  @override
  String get logsUploadTooltip => 'Upload now';

  @override
  String get logsShareTooltip => 'Share all';

  @override
  String get logsClearTooltip => 'Clear all';

  @override
  String get logsClearConfirmTitle => 'Delete all logs?';

  @override
  String get logsClearConfirmBody => 'This action cannot be undone.';

  @override
  String get logsClearConfirmButton => 'Delete';

  @override
  String logsPending(int count) {
    return '$count pending upload';
  }

  @override
  String get logsEmpty => 'No logs yet';

  @override
  String get logsSearchHint => 'Search…';

  @override
  String get logsCopiedToClipboard => 'Copied to clipboard';

  @override
  String get mapNoRoute => 'No route';

  @override
  String historyBestLapSuffix(String duration) {
    return ' · best $duration';
  }

  @override
  String get navFreeRide => 'Free ride';

  @override
  String get freeRideTitle => 'Free ride';

  @override
  String get freeRideIdleTitle => 'Ride without a destination';

  @override
  String get freeRideIdleMessage =>
      'Record your path in real time without a predefined route. Speed, distance and position are tracked automatically.';

  @override
  String get freeRideStartButton => 'Start recording';

  @override
  String get freeRideSetupTitle => 'New recording';

  @override
  String get freeRideSetupNameLabel => 'Name (optional)';

  @override
  String get freeRideElapsedLabel => 'Elapsed';

  @override
  String get freeRideDistanceLabel => 'Distance';

  @override
  String get freeRideSpeedLabel => 'Speed';

  @override
  String get freeRideMaxSpeedLabel => 'Max speed';

  @override
  String get freeRideAvgSpeedLabel => 'Avg speed';

  @override
  String get freeRideFinishButton => 'Finish ride';

  @override
  String get freeRideCompleteTitle => 'Ride complete';

  @override
  String get freeRideSavedSnackBar => 'Free ride saved';

  @override
  String get freeRideSaveAsRouteButton => 'Save as reusable route';

  @override
  String get freeRideDiscardButton => 'Finish without saving route';

  @override
  String get freeRideNewRideButton => 'New ride';

  @override
  String get freeRideSaveRouteDialogTitle => 'Save as route';

  @override
  String get freeRideNameLabel => 'Name';

  @override
  String get freeRideDescriptionLabel => 'Description (optional)';

  @override
  String get freeRideDifficultyLabel => 'Difficulty';

  @override
  String freeRideRouteSavedSnack(String name) {
    return 'Route \"$name\" saved';
  }

  @override
  String freeRidePointsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String get historyNoEntriesTitle => 'No activity recorded yet';

  @override
  String get historyNoEntriesMessage =>
      'Go for a free ride or record a session on a route.';

  @override
  String get historyFreeRideLabel => 'Free ride';

  @override
  String historyFreeRideSubtitle(String date, String distance) {
    return '$date · $distance';
  }

  @override
  String get historyDeleteFreeRideTitle => 'Delete free ride';

  @override
  String get historyFreeRideTitle => 'Free ride detail';

  @override
  String get historyRenameFreeRideTitle => 'Rename ride';

  @override
  String get historyRenameFreeRideLabel => 'Name';

  @override
  String get historyRenamedSnack => 'Name updated';

  @override
  String get historyRenameRouteTitle => 'Rename route';

  @override
  String get historyRenameRouteLabel => 'Name';

  @override
  String get historySearchHint => 'Search…';

  @override
  String get historyFiltersTitle => 'Filters';

  @override
  String get historyFiltersOpen => 'Open filters';

  @override
  String get historyFiltersApply => 'Apply';

  @override
  String get historyFiltersClear => 'Clear';

  @override
  String get historyFilterKindLabel => 'Type';

  @override
  String get historyFilterKindSession => 'Session';

  @override
  String get historyFilterKindFreeRide => 'Free ride';

  @override
  String get historyFilterVehicleLabel => 'Vehicle';

  @override
  String get historyNoVehicle => 'No vehicle';

  @override
  String get historyFilterDateRangeLabel => 'Date range';

  @override
  String get historyDateLast7Days => 'Last 7 days';

  @override
  String get historyDateLast30Days => 'Last 30 days';

  @override
  String get historyDateThisYear => 'This year';

  @override
  String get historyDateCustom => 'Custom';

  @override
  String get historyFilterMinDistanceLabel => 'Min distance';

  @override
  String historyFilterMinDistanceChip(String value) {
    return '≥ $value';
  }

  @override
  String historyFilterVehicleChipMany(int count) {
    return 'Vehicles ($count)';
  }

  @override
  String get historyFilteredEmptyTitle => 'No matches';

  @override
  String get historyFilteredEmptyAction => 'Clear filters';

  @override
  String get historyFilterGroupByRoute => 'Group by route';

  @override
  String get historyGroupFreeRides => 'Free rides';

  @override
  String get historyGroupChip => 'Grouped by route';

  @override
  String historyGroupSubtitle(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0 · last $date';
  }

  @override
  String get routesTitle => 'My routes';

  @override
  String get routesViewList => 'List';

  @override
  String get routesViewGrid => 'Grid';

  @override
  String routesSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
      zero: 'No sessions',
    );
    return '$_temp0';
  }

  @override
  String routesBestLap(String time) {
    return 'Best: $time';
  }

  @override
  String get routesDetailTitle => 'Route detail';

  @override
  String get navGarage => 'Garage';

  @override
  String get garageTitle => 'My garage';

  @override
  String get garageNoVehiclesTitle => 'No vehicles yet';

  @override
  String get garageNoVehiclesMessage =>
      'Add your first car, bike, or kart to track which vehicle you use on each session.';

  @override
  String get garageAddVehicleButton => 'Add vehicle';

  @override
  String get garageViewList => 'List';

  @override
  String get garageViewGrid => 'Grid';

  @override
  String get garageDeleteVehicleTitle => 'Delete vehicle';

  @override
  String garageDeleteVehicleConfirm(String vehicleName) {
    return 'Delete \"$vehicleName\"? This cannot be undone.';
  }

  @override
  String get garageVehicleSavedSnack => 'Vehicle saved';

  @override
  String get garageVehicleDeletedSnack => 'Vehicle deleted';

  @override
  String get garagePhotoUpdated => 'Photo updated';

  @override
  String get garageErrorUnexpected => 'Something went wrong. Try again.';

  @override
  String get garageChangePhoto => 'Change photo';

  @override
  String get vehicleFormTitleNew => 'New vehicle';

  @override
  String get vehicleFormTitleEdit => 'Edit vehicle';

  @override
  String get vehicleFormNameLabel => 'Name';

  @override
  String get vehicleFormNameRequired => 'Enter a name';

  @override
  String get vehicleFormNameMinLength => 'Minimum 2 characters';

  @override
  String get vehicleFormTypeLabel => 'Type';

  @override
  String get vehicleFormModelLabel => 'Model (optional)';

  @override
  String get vehicleFormYearLabel => 'Year (optional)';

  @override
  String get vehicleFormHorsepowerLabel => 'Horsepower (optional)';

  @override
  String get vehicleFormTorqueLabel => 'Torque Nm (optional)';

  @override
  String get vehicleFormWeightLabel => 'Weight kg (optional)';

  @override
  String get vehicleFormDrivetrainLabel => 'Drivetrain (optional)';

  @override
  String get vehicleFormNotesLabel => 'Notes (optional)';

  @override
  String get vehicleFormNotesHint => 'Tire setup, modifications, etc.';

  @override
  String get vehicleFormSaveButton => 'Save';

  @override
  String get vehicleTypeCar => 'Car';

  @override
  String get vehicleTypeMotorcycle => 'Motorcycle';

  @override
  String get vehicleTypeBicycle => 'Bicycle';

  @override
  String get vehicleTypeGoKart => 'Go-kart';

  @override
  String get vehicleTypeOther => 'Other';

  @override
  String get drivetrainFront => 'Front-wheel drive';

  @override
  String get drivetrainRear => 'Rear-wheel drive';

  @override
  String get drivetrainAllWheel => 'All-wheel drive';

  @override
  String get vehicleDetailSpecs => 'Specs';

  @override
  String vehicleDetailHorsepower(int hp) {
    return '$hp hp';
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
  String get vehiclePickerLabel => 'Vehicle';

  @override
  String get vehiclePickerOnFoot => 'On foot';

  @override
  String get vehiclePickerSelectVehicle => 'Select a vehicle';

  @override
  String get elevationRangeLabel => 'Elevation';

  @override
  String get routeExpectedTimeLabel => 'Normal time';

  @override
  String elevationRangeValue(String value) {
    return '$value m';
  }

  @override
  String elevationRangeValueFeet(String value) {
    return '$value ft';
  }

  @override
  String get backgroundNotificationTitle => 'Splitway · Recording route';

  @override
  String get backgroundDeniedBanner =>
      'Recording will stop if you leave the app. Grant \"Always\" location permission for background recording.';

  @override
  String get backgroundOpenSettings => 'Open settings';

  @override
  String get backgroundDialogTitle => 'Background recording';

  @override
  String get backgroundDialogBody =>
      'To keep recording your route when the screen is off or you switch apps, you need to allow location access \"Always\".\n\nGo to Settings > Permissions > Location and select \"Allow always\".';

  @override
  String get backgroundDialogOpenSettings => 'Open settings';

  @override
  String get backgroundDialogSkip => 'Continue without background';

  @override
  String get notificationDialogTitle => 'Enable notifications';

  @override
  String get notificationDialogBody =>
      'Splitway uses notifications to keep you informed during route recording — showing elapsed time, distance, and tracking status even when the app is in the background.';

  @override
  String get notificationDialogAllow => 'Allow notifications';

  @override
  String get notificationDialogSkip => 'Not now';

  @override
  String get mapStyleOutdoors => 'Outdoor';

  @override
  String get mapStyleSatelliteStreets => 'Satellite';

  @override
  String get mapStyleDark => 'Dark';

  @override
  String get mapStyleLayersTooltip => 'Map style';

  @override
  String get heatmapToggleOn => 'Show speed heatmap';

  @override
  String get heatmapToggleOff => 'Hide speed heatmap';

  @override
  String get heatmapLegendTitle => 'Speed';

  @override
  String get editorSearchLocationHint => 'Search location...';

  @override
  String get editorSearchNoResults => 'No results found';

  @override
  String get navSpeed => 'Speed test';

  @override
  String get drawerSpeed => 'Speed test';

  @override
  String get speedSetupTitle => 'Speed test';

  @override
  String get speedSetupVehicleSection => 'Vehicle';

  @override
  String get speedSetupVehicleEmpty => 'No vehicles in your garage yet';

  @override
  String get speedSetupMetricsSection => 'What to measure';

  @override
  String get speedSetupCountdownSection => 'Countdown';

  @override
  String get speedSetupNameSection => 'Name (optional)';

  @override
  String get speedSetupNameHint => 'Leave empty for default';

  @override
  String get speedSetupViewSection => 'Results view';

  @override
  String get speedSetupViewList => 'List';

  @override
  String get speedSetupViewGrid => 'Grid';

  @override
  String get speedSetupContinue => 'Continue';

  @override
  String speedSetupSecondsValue(int n) {
    return '${n}s';
  }

  @override
  String get speedReadyMessage => 'When you are ready, press Start';

  @override
  String get speedReadyStart => 'START';

  @override
  String get speedSessionGo => 'GO!';

  @override
  String get speedFinishedTitle => 'Session complete';

  @override
  String get speedFinishedSave => 'Save';

  @override
  String get speedFinishedDiscard => 'Discard';

  @override
  String get speedFinishedManualStop => 'Stop';

  @override
  String get speedFalseStartTitle => 'FALSE START';

  @override
  String get speedFalseStartSubtitle => 'You moved before the final beep';

  @override
  String get speedFalseStartRetry => 'RETRY';

  @override
  String get speedFalseStartCancel => 'Cancel';

  @override
  String get speedCategoryDrag => 'Drag';

  @override
  String get speedCategoryStopwatch => 'Stopwatch';

  @override
  String get speedCategoryOther => 'Other';

  @override
  String get speedMetricReactionTime => 'Reaction time';

  @override
  String get speedMetricSixtyFoot => '60 ft';

  @override
  String get speedMetricEighthMile => '1/8 mile';

  @override
  String get speedMetricQuarterMile => '1/4 mile';

  @override
  String get speedMetricZeroTo50 => '0-50';

  @override
  String get speedMetricZeroTo100 => '0-100';

  @override
  String get speedMetricZeroTo200 => '0-200';

  @override
  String get speedMetricTopSpeed => 'Top speed';

  @override
  String get speedHistoryTab => 'Speed test';

  @override
  String get speedHistoryEmpty => 'No speed sessions yet';

  @override
  String get speedHistoryDeleteTooltip => 'Delete';

  @override
  String get speedHistoryDeleteTitle => 'Delete session';

  @override
  String speedHistoryDeleteConfirm(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get speedDetailEditNameTooltip => 'Edit name';

  @override
  String get speedDetailEditNameTitle => 'Edit name';

  @override
  String get speedDetailEditNameHint => 'Session name';

  @override
  String get speedDetailEditNameSave => 'Save';

  @override
  String get speedDetailEditNameCancel => 'Cancel';

  @override
  String get speedDetailEditNameError => 'Could not save name';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsEmptyTitle => 'No data yet';

  @override
  String get statsEmptyMessage =>
      'Record a session, free ride, or speed test to see your statistics here.';

  @override
  String get statsOverviewSection => 'Overview';

  @override
  String get statsTotalSessions => 'Total activities';

  @override
  String get statsTotalDistance => 'Total distance';

  @override
  String get statsTotalTime => 'Total time';

  @override
  String get statsVehiclesOwned => 'Vehicles';

  @override
  String get statsPersonalBestsSection => 'Personal bests';

  @override
  String get statsRecordsSection => 'Records';

  @override
  String get statsTopSpeedRecord => 'Top speed';

  @override
  String get statsLongestRide => 'Longest ride';

  @override
  String get statsLongestSession => 'Longest session';

  @override
  String get statsActivitySection => 'Last 8 weeks';

  @override
  String get statsActivityWeekly => 'Activities per week';

  @override
  String get statsByVehicleSection => 'By vehicle';

  @override
  String get statsNoBestYet => '—';

  @override
  String statsActivitiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activities',
      one: '1 activity',
      zero: 'No activities',
    );
    return '$_temp0';
  }

  @override
  String get statsBestQuarterMileShort => 'Best 1/4 mi';

  @override
  String get statsNoSpeedSessionsForVehicle => 'No speed tests';

  @override
  String get statsUnknownVehicle => 'Unknown vehicle';

  @override
  String get statsMetricSelectorLabel => 'Metric:';

  @override
  String get recordingPauseButton => 'Pause ride';

  @override
  String get recordingResumeButton => 'Resume';
}
