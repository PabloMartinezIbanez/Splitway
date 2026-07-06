import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Splitway'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Smart stopwatch for routes'**
  String get appTagline;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get commonClose;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get commonDiscard;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @navEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get navEditor;

  /// No description provided for @navSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get navSession;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get navRoutes;

  /// No description provided for @drawerMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get drawerMenu;

  /// No description provided for @drawerDefaultUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get drawerDefaultUser;

  /// No description provided for @drawerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get drawerSettings;

  /// No description provided for @drawerStats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get drawerStats;

  /// No description provided for @drawerHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get drawerHelp;

  /// No description provided for @drawerSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get drawerSignOut;

  /// No description provided for @drawerSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get drawerSignIn;

  /// No description provided for @drawerAppVersion.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String drawerAppVersion(String version);

  /// No description provided for @drawerSyncSynced.
  ///
  /// In en, this message translates to:
  /// **'SYNCED'**
  String get drawerSyncSynced;

  /// No description provided for @drawerSyncSyncedNow.
  ///
  /// In en, this message translates to:
  /// **'SYNCED · now'**
  String get drawerSyncSyncedNow;

  /// No description provided for @drawerSyncSyncedMinutes.
  ///
  /// In en, this message translates to:
  /// **'SYNCED · {minutes} min ago'**
  String drawerSyncSyncedMinutes(int minutes);

  /// No description provided for @drawerSyncSyncedAt.
  ///
  /// In en, this message translates to:
  /// **'SYNCED · {time}'**
  String drawerSyncSyncedAt(String time);

  /// No description provided for @drawerSyncSyncing.
  ///
  /// In en, this message translates to:
  /// **'SYNCING…'**
  String get drawerSyncSyncing;

  /// No description provided for @drawerSyncError.
  ///
  /// In en, this message translates to:
  /// **'SYNC ERROR'**
  String get drawerSyncError;

  /// No description provided for @drawerSyncOffline.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get drawerSyncOffline;

  /// No description provided for @drawerSyncPending.
  ///
  /// In en, this message translates to:
  /// **'PENDING CHANGES'**
  String get drawerSyncPending;

  /// No description provided for @drawerProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get drawerProfile;

  /// No description provided for @loginBannerDefault.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get loginBannerDefault;

  /// No description provided for @loginEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmailHint;

  /// No description provided for @loginPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordHint;

  /// No description provided for @loginEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an email'**
  String get loginEmailRequired;

  /// No description provided for @loginEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get loginEmailInvalid;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get loginPasswordRequired;

  /// No description provided for @loginPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum 6 characters'**
  String get loginPasswordMinLength;

  /// No description provided for @loginConfirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get loginConfirmPasswordHint;

  /// No description provided for @loginPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get loginPasswordMismatch;

  /// No description provided for @loginSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSignInButton;

  /// No description provided for @loginSignUpButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get loginSignUpButton;

  /// No description provided for @loginOrSeparator.
  ///
  /// In en, this message translates to:
  /// **'— or —'**
  String get loginOrSeparator;

  /// No description provided for @loginContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get loginContinueWithGoogle;

  /// No description provided for @loginToggleToSignUp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get loginToggleToSignUp;

  /// No description provided for @loginToggleToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get loginToggleToSignIn;

  /// No description provided for @loginToggleSignUpAction.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get loginToggleSignUpAction;

  /// No description provided for @loginToggleSignInAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginToggleSignInAction;

  /// No description provided for @loginSkipButton.
  ///
  /// In en, this message translates to:
  /// **'Continue without account'**
  String get loginSkipButton;

  /// No description provided for @loginNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get loginNicknameHint;

  /// No description provided for @loginNicknameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a nickname'**
  String get loginNicknameRequired;

  /// No description provided for @loginNicknameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum 2 characters'**
  String get loginNicknameMinLength;

  /// No description provided for @loginConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox!'**
  String get loginConfirmationTitle;

  /// No description provided for @loginConfirmationBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to\n{email}\n\nClick the link to activate your account and sign in.'**
  String loginConfirmationBody(String email);

  /// No description provided for @authErrorGoogleToken.
  ///
  /// In en, this message translates to:
  /// **'Could not retrieve Google token.'**
  String get authErrorGoogleToken;

  /// No description provided for @authErrorEmailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Sign in.'**
  String get authErrorEmailAlreadyRegistered;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email before signing in.'**
  String get authErrorEmailNotConfirmed;

  /// No description provided for @authErrorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get authErrorPasswordTooShort;

  /// No description provided for @authErrorNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection. Try again.'**
  String get authErrorNoConnection;

  /// No description provided for @authErrorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error. Try again.'**
  String get authErrorUnexpected;

  /// No description provided for @authErrorBanned.
  ///
  /// In en, this message translates to:
  /// **'Your account is banned.'**
  String get authErrorBanned;

  /// No description provided for @authErrorBannedUntil.
  ///
  /// In en, this message translates to:
  /// **'Your account is banned until {date}.'**
  String authErrorBannedUntil(DateTime date);

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get loginForgotPassword;

  /// No description provided for @loginForgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get loginForgotPasswordTitle;

  /// No description provided for @loginForgotPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a link to reset your password.'**
  String get loginForgotPasswordBody;

  /// No description provided for @loginForgotPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get loginForgotPasswordButton;

  /// No description provided for @loginForgotPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'We sent a reset link to {email}. Check your inbox.'**
  String loginForgotPasswordSuccess(String email);

  /// No description provided for @loginForgotPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Could not send reset email. Try again.'**
  String get loginForgotPasswordError;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileAvatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated'**
  String get profileAvatarUpdated;

  /// No description provided for @profileErrorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Could not update avatar. Try again.'**
  String get profileErrorUnexpected;

  /// No description provided for @profileNicknameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Nickname updated'**
  String get profileNicknameUpdated;

  /// No description provided for @profileErrorCooldown.
  ///
  /// In en, this message translates to:
  /// **'Nickname can only be changed after the cooldown.'**
  String get profileErrorCooldown;

  /// No description provided for @profileBioUpdated.
  ///
  /// In en, this message translates to:
  /// **'Bio updated'**
  String get profileBioUpdated;

  /// No description provided for @profileChangeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change avatar'**
  String get profileChangeAvatar;

  /// No description provided for @profileNicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get profileNicknameLabel;

  /// No description provided for @profileNicknameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a nickname'**
  String get profileNicknameRequired;

  /// No description provided for @profileNicknameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum 2 characters'**
  String get profileNicknameMinLength;

  /// No description provided for @profileNicknameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Maximum 30 characters'**
  String get profileNicknameTooLong;

  /// No description provided for @profileBioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileBioLabel;

  /// No description provided for @profileBioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell others a little bit about yourself'**
  String get profileBioHint;

  /// No description provided for @profileNicknameCooldownDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String profileNicknameCooldownDays(int days);

  /// No description provided for @profileNicknameCooldownHours.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 hour} other{{hours} hours}}'**
  String profileNicknameCooldownHours(int hours);

  /// No description provided for @profileNicknameCooldown.
  ///
  /// In en, this message translates to:
  /// **'Nickname change available in'**
  String get profileNicknameCooldown;

  /// No description provided for @profileEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmailLabel;

  /// No description provided for @profileDateOfBirthLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get profileDateOfBirthLabel;

  /// No description provided for @loginDateOfBirthHint.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get loginDateOfBirthHint;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get onboardingTitle;

  /// No description provided for @onboardingDescription.
  ///
  /// In en, this message translates to:
  /// **'We need a few things to finish setting up your account. The password will let you sign in with email too.'**
  String get onboardingDescription;

  /// No description provided for @onboardingSubmit.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get onboardingSubmit;

  /// No description provided for @onboardingSubmitLoading.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get onboardingSubmitLoading;

  /// No description provided for @onboardingDobInvalid.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 13 years old.'**
  String get onboardingDobInvalid;

  /// No description provided for @onboardingProfileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the profile. Please try again.'**
  String get onboardingProfileFailed;

  /// No description provided for @onboardingPasswordFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not set the password.'**
  String get onboardingPasswordFailed;

  /// No description provided for @onboardingPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum 8 characters.'**
  String get onboardingPasswordMinLength;

  /// No description provided for @editorTitle.
  ///
  /// In en, this message translates to:
  /// **'Route editor'**
  String get editorTitle;

  /// No description provided for @editorNewRouteTooltip.
  ///
  /// In en, this message translates to:
  /// **'New route'**
  String get editorNewRouteTooltip;

  /// No description provided for @editorNewRouteButton.
  ///
  /// In en, this message translates to:
  /// **'New route'**
  String get editorNewRouteButton;

  /// No description provided for @editorNoRoutesTitle.
  ///
  /// In en, this message translates to:
  /// **'No routes yet'**
  String get editorNoRoutesTitle;

  /// No description provided for @editorNoRoutesMessage.
  ///
  /// In en, this message translates to:
  /// **'Create your first route to start timing.'**
  String get editorNoRoutesMessage;

  /// No description provided for @editorSectorsLabel.
  ///
  /// In en, this message translates to:
  /// **'Sectors'**
  String get editorSectorsLabel;

  /// No description provided for @editorSectorCenter.
  ///
  /// In en, this message translates to:
  /// **'Center: {lat}, {lng}'**
  String editorSectorCenter(String lat, String lng);

  /// No description provided for @editorStartFinishLabel.
  ///
  /// In en, this message translates to:
  /// **'Start / finish'**
  String get editorStartFinishLabel;

  /// No description provided for @editorCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created on {date}'**
  String editorCreatedAt(String date);

  /// No description provided for @editorDeleteRouteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete route'**
  String get editorDeleteRouteButton;

  /// No description provided for @editorDeleteRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete route'**
  String get editorDeleteRouteTitle;

  /// No description provided for @editorDeleteRouteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{routeName}\" and all its sessions?'**
  String editorDeleteRouteConfirm(String routeName);

  /// No description provided for @editorModeAppendPath.
  ///
  /// In en, this message translates to:
  /// **'Append path'**
  String get editorModeAppendPath;

  /// No description provided for @editorModeStartGate.
  ///
  /// In en, this message translates to:
  /// **'Start/finish'**
  String get editorModeStartGate;

  /// No description provided for @editorModeSectorGate.
  ///
  /// In en, this message translates to:
  /// **'Sector gate'**
  String get editorModeSectorGate;

  /// No description provided for @editorDrawingTitle.
  ///
  /// In en, this message translates to:
  /// **'Drawing: {draftName}'**
  String editorDrawingTitle(String draftName);

  /// No description provided for @editorCancelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get editorCancelTooltip;

  /// No description provided for @editorCancelDrawingTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel drawing'**
  String get editorCancelDrawingTitle;

  /// No description provided for @editorCancelDrawingWarning.
  ///
  /// In en, this message translates to:
  /// **'Unsaved points will be discarded.'**
  String get editorCancelDrawingWarning;

  /// No description provided for @editorNoMapboxToken.
  ///
  /// In en, this message translates to:
  /// **'Mapbox token not configured. The interactive map is disabled; add a token and restart to draw.'**
  String get editorNoMapboxToken;

  /// No description provided for @editorSegmentPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get editorSegmentPath;

  /// No description provided for @editorSegmentStartFinish.
  ///
  /// In en, this message translates to:
  /// **'Start / finish'**
  String get editorSegmentStartFinish;

  /// No description provided for @editorSegmentAddSector.
  ///
  /// In en, this message translates to:
  /// **'Add sector'**
  String get editorSegmentAddSector;

  /// No description provided for @editorSegmentFreehand.
  ///
  /// In en, this message translates to:
  /// **'Freehand'**
  String get editorSegmentFreehand;

  /// No description provided for @editorModeFreehand.
  ///
  /// In en, this message translates to:
  /// **'Draw freehand'**
  String get editorModeFreehand;

  /// No description provided for @editorUndoFreehand.
  ///
  /// In en, this message translates to:
  /// **'Undo stroke'**
  String get editorUndoFreehand;

  /// No description provided for @editorUndoPoint.
  ///
  /// In en, this message translates to:
  /// **'Undo point'**
  String get editorUndoPoint;

  /// No description provided for @editorPathPoints.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No points} =1{1 point} other{{count} points}}'**
  String editorPathPoints(int count);

  /// No description provided for @editorStartGateUndefined.
  ///
  /// In en, this message translates to:
  /// **'No start'**
  String get editorStartGateUndefined;

  /// No description provided for @editorStartGateDefined.
  ///
  /// In en, this message translates to:
  /// **'Start defined'**
  String get editorStartGateDefined;

  /// No description provided for @editorSectorsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No sectors} =1{1 sector} other{{count} sectors}}'**
  String editorSectorsCount(int count);

  /// No description provided for @editorWaitingSecondPoint.
  ///
  /// In en, this message translates to:
  /// **'Waiting for 2nd point…'**
  String get editorWaitingSecondPoint;

  /// No description provided for @editorDifficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get editorDifficultyEasy;

  /// No description provided for @editorDifficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get editorDifficultyMedium;

  /// No description provided for @editorDifficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get editorDifficultyHard;

  /// No description provided for @editorHideSectors.
  ///
  /// In en, this message translates to:
  /// **'Hide sectors'**
  String get editorHideSectors;

  /// No description provided for @editorShowSectors.
  ///
  /// In en, this message translates to:
  /// **'Show sectors'**
  String get editorShowSectors;

  /// No description provided for @editorNoSectorsHint.
  ///
  /// In en, this message translates to:
  /// **'No sectors'**
  String get editorNoSectorsHint;

  /// No description provided for @editorClosedLoop.
  ///
  /// In en, this message translates to:
  /// **'Closed loop'**
  String get editorClosedLoop;

  /// No description provided for @editorOpenRoute.
  ///
  /// In en, this message translates to:
  /// **'Open route'**
  String get editorOpenRoute;

  /// No description provided for @editorRouteSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'Saved \"{name}\"'**
  String editorRouteSavedSnack(String name);

  /// No description provided for @editorSnapFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server to snap the route to roads. Showing straight segments until the connection is restored.'**
  String get editorSnapFailedMessage;

  /// No description provided for @editorDrawingModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Drawing mode'**
  String get editorDrawingModeTooltip;

  /// No description provided for @editorRoutingProfileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Routing mode'**
  String get editorRoutingProfileTooltip;

  /// No description provided for @editorRoutingProfileDriving.
  ///
  /// In en, this message translates to:
  /// **'Road'**
  String get editorRoutingProfileDriving;

  /// No description provided for @editorRoutingProfileWalking.
  ///
  /// In en, this message translates to:
  /// **'Trail'**
  String get editorRoutingProfileWalking;

  /// No description provided for @editorRoutingProfileCycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get editorRoutingProfileCycling;

  /// No description provided for @editorNewRouteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New route'**
  String get editorNewRouteDialogTitle;

  /// No description provided for @editorEditRouteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit route'**
  String get editorEditRouteDialogTitle;

  /// No description provided for @editorNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get editorNameLabel;

  /// No description provided for @editorDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get editorDescriptionLabel;

  /// No description provided for @editorDifficultyLabel.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get editorDifficultyLabel;

  /// No description provided for @editorStartDrawingButton.
  ///
  /// In en, this message translates to:
  /// **'Start drawing'**
  String get editorStartDrawingButton;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get historyTitle;

  /// No description provided for @historyNoSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No sessions recorded yet'**
  String get historyNoSessionsTitle;

  /// No description provided for @historyNoSessionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Go to the Session tab, pick a route, and tap \"Start\".'**
  String get historyNoSessionsMessage;

  /// No description provided for @historyDeletedRoute.
  ///
  /// In en, this message translates to:
  /// **'Deleted route'**
  String get historyDeletedRoute;

  /// No description provided for @historySessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{date} · {lapCount, plural, =1{1 lap} other{{lapCount} laps}}{bestLap}'**
  String historySessionSubtitle(String date, int lapCount, String bestLap);

  /// No description provided for @historySessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get historySessionTitle;

  /// No description provided for @historyDeleteSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get historyDeleteSessionTitle;

  /// No description provided for @historyIrreversibleWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get historyIrreversibleWarning;

  /// No description provided for @historySessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Session not found'**
  String get historySessionNotFound;

  /// No description provided for @historyLapsLabel.
  ///
  /// In en, this message translates to:
  /// **'Laps'**
  String get historyLapsLabel;

  /// No description provided for @historyLapItem.
  ///
  /// In en, this message translates to:
  /// **'Lap {n}'**
  String historyLapItem(int n);

  /// No description provided for @historyLapsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No laps recorded in this session'**
  String get historyLapsEmpty;

  /// No description provided for @historySectorsLabel.
  ///
  /// In en, this message translates to:
  /// **'Sectors'**
  String get historySectorsLabel;

  /// No description provided for @historySectorsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sectors recorded in this session'**
  String get historySectorsEmpty;

  /// No description provided for @historySectorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lap {lapNum} · {speed}'**
  String historySectorSubtitle(int lapNum, String speed);

  /// No description provided for @historyDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get historyDistanceLabel;

  /// No description provided for @historyMaxSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Max speed'**
  String get historyMaxSpeedLabel;

  /// No description provided for @historyAvgSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Avg speed'**
  String get historyAvgSpeedLabel;

  /// No description provided for @sessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Live session'**
  String get sessionTitle;

  /// No description provided for @sessionNoRoutesTitle.
  ///
  /// In en, this message translates to:
  /// **'No routes to run'**
  String get sessionNoRoutesTitle;

  /// No description provided for @sessionNoRoutesMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a route in the Editor tab first to record a session.'**
  String get sessionNoRoutesMessage;

  /// No description provided for @sessionSelectRoute.
  ///
  /// In en, this message translates to:
  /// **'Select a route'**
  String get sessionSelectRoute;

  /// No description provided for @sessionTelemetrySource.
  ///
  /// In en, this message translates to:
  /// **'Telemetry source'**
  String get sessionTelemetrySource;

  /// No description provided for @sessionSourceSimulated.
  ///
  /// In en, this message translates to:
  /// **'Simulated'**
  String get sessionSourceSimulated;

  /// No description provided for @sessionSourceRealGps.
  ///
  /// In en, this message translates to:
  /// **'Real GPS'**
  String get sessionSourceRealGps;

  /// No description provided for @sessionStartButton.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get sessionStartButton;

  /// No description provided for @sessionConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Session setup'**
  String get sessionConfigTitle;

  /// No description provided for @sessionConfigNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Session name (optional)'**
  String get sessionConfigNameLabel;

  /// No description provided for @sessionConfigNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Morning practice'**
  String get sessionConfigNameHint;

  /// No description provided for @sessionConfigIncludeHistoricalTitle.
  ///
  /// In en, this message translates to:
  /// **'Compete against my best on this route'**
  String get sessionConfigIncludeHistoricalTitle;

  /// No description provided for @sessionConfigIncludeHistoricalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When on, your best previous sector and lap times on this route are shown as the target to beat. When off, you only compete against this session.'**
  String get sessionConfigIncludeHistoricalSubtitle;

  /// No description provided for @sessionConfigStartButton.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get sessionConfigStartButton;

  /// No description provided for @sessionReferenceLapLabel.
  ///
  /// In en, this message translates to:
  /// **'To beat'**
  String get sessionReferenceLapLabel;

  /// No description provided for @sessionSimulatedHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Simulate point\" to advance, or \"Auto lap\" to run a lap automatically.'**
  String get sessionSimulatedHint;

  /// No description provided for @sessionRealGpsHint.
  ///
  /// In en, this message translates to:
  /// **'Make sure location is enabled. Points are captured every second.'**
  String get sessionRealGpsHint;

  /// No description provided for @sessionSavedSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Session saved'**
  String get sessionSavedSnackBar;

  /// No description provided for @sessionNotStartedSnackBar.
  ///
  /// In en, this message translates to:
  /// **'No route recorded — you didn\'t cross the start line'**
  String get sessionNotStartedSnackBar;

  /// No description provided for @sessionFinishButton.
  ///
  /// In en, this message translates to:
  /// **'Finish and save'**
  String get sessionFinishButton;

  /// No description provided for @sessionCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Session complete'**
  String get sessionCompleteTitle;

  /// No description provided for @sessionRouteLabel.
  ///
  /// In en, this message translates to:
  /// **'Route: {routeName}'**
  String sessionRouteLabel(String routeName);

  /// No description provided for @sessionLapsLabel.
  ///
  /// In en, this message translates to:
  /// **'Laps'**
  String get sessionLapsLabel;

  /// No description provided for @sessionNewSessionButton.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get sessionNewSessionButton;

  /// No description provided for @sessionCurrentLapLabel.
  ///
  /// In en, this message translates to:
  /// **'Current lap'**
  String get sessionCurrentLapLabel;

  /// No description provided for @sessionLapNumber.
  ///
  /// In en, this message translates to:
  /// **'#{n}'**
  String sessionLapNumber(int n);

  /// No description provided for @sessionNoLapYet.
  ///
  /// In en, this message translates to:
  /// **'–'**
  String get sessionNoLapYet;

  /// No description provided for @sessionLapTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Lap time'**
  String get sessionLapTimeLabel;

  /// No description provided for @sessionBestLapLabel.
  ///
  /// In en, this message translates to:
  /// **'Best lap'**
  String get sessionBestLapLabel;

  /// No description provided for @sessionElapsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get sessionElapsedLabel;

  /// No description provided for @sessionTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get sessionTargetLabel;

  /// No description provided for @sessionFinishedOverlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Route finished'**
  String get sessionFinishedOverlayTitle;

  /// No description provided for @sessionContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get sessionContinueButton;

  /// No description provided for @sessionTimeGainedLabel.
  ///
  /// In en, this message translates to:
  /// **'You gained'**
  String get sessionTimeGainedLabel;

  /// No description provided for @sessionTimeLostLabel.
  ///
  /// In en, this message translates to:
  /// **'You lost'**
  String get sessionTimeLostLabel;

  /// No description provided for @sessionTimeDeltaFaster.
  ///
  /// In en, this message translates to:
  /// **'{time} faster'**
  String sessionTimeDeltaFaster(String time);

  /// No description provided for @sessionTimeDeltaSlower.
  ///
  /// In en, this message translates to:
  /// **'{time} slower'**
  String sessionTimeDeltaSlower(String time);

  /// No description provided for @sessionAwaitingStart.
  ///
  /// In en, this message translates to:
  /// **'Waiting for first finish-line crossing…'**
  String get sessionAwaitingStart;

  /// No description provided for @sessionCrossingSectors.
  ///
  /// In en, this message translates to:
  /// **'Crossing sectors…'**
  String get sessionCrossingSectors;

  /// No description provided for @sessionLastSector.
  ///
  /// In en, this message translates to:
  /// **'Last sector: {sectorId}'**
  String sessionLastSector(String sectorId);

  /// No description provided for @sessionDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get sessionDistanceLabel;

  /// No description provided for @sessionMaxSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Max speed'**
  String get sessionMaxSpeedLabel;

  /// No description provided for @sessionAvgSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Avg speed'**
  String get sessionAvgSpeedLabel;

  /// No description provided for @sessionLapsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Laps'**
  String get sessionLapsCountLabel;

  /// No description provided for @sessionPermissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Location permission granted.'**
  String get sessionPermissionGranted;

  /// No description provided for @sessionPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied. Accept the system dialog or switch to \"Simulated\".'**
  String get sessionPermissionDenied;

  /// No description provided for @sessionPermissionPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission permanently blocked. Enable it manually in system settings.'**
  String get sessionPermissionPermanentlyDenied;

  /// No description provided for @sessionServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services disabled. Turn them on in system settings.'**
  String get sessionServicesDisabled;

  /// No description provided for @sessionGpsStatus.
  ///
  /// In en, this message translates to:
  /// **'Real GPS · {count, plural, =1{1 sample} other{{count} samples}}'**
  String sessionGpsStatus(int count);

  /// No description provided for @sessionGpsAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy: {accuracy} m · {lat}, {lng}'**
  String sessionGpsAccuracy(String accuracy, String lat, String lng);

  /// No description provided for @sessionAwaitingFirstFix.
  ///
  /// In en, this message translates to:
  /// **'Waiting for first fix…'**
  String get sessionAwaitingFirstFix;

  /// No description provided for @gpsSignalLabel.
  ///
  /// In en, this message translates to:
  /// **'GPS Signal'**
  String get gpsSignalLabel;

  /// No description provided for @gpsSignalNone.
  ///
  /// In en, this message translates to:
  /// **'No signal'**
  String get gpsSignalNone;

  /// No description provided for @gpsSignalLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get gpsSignalLow;

  /// No description provided for @gpsSignalMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get gpsSignalMedium;

  /// No description provided for @gpsSignalHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get gpsSignalHigh;

  /// No description provided for @sessionSimulatePoint.
  ///
  /// In en, this message translates to:
  /// **'Simulate point'**
  String get sessionSimulatePoint;

  /// No description provided for @sessionPauseAuto.
  ///
  /// In en, this message translates to:
  /// **'Pause auto'**
  String get sessionPauseAuto;

  /// No description provided for @sessionAutoLap.
  ///
  /// In en, this message translates to:
  /// **'Auto lap'**
  String get sessionAutoLap;

  /// No description provided for @sessionSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Speed:'**
  String get sessionSpeedLabel;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSection;

  /// No description provided for @settingsLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the app display language.'**
  String get settingsLanguageDescription;

  /// No description provided for @unitMeters.
  ///
  /// In en, this message translates to:
  /// **'{value} m'**
  String unitMeters(String value);

  /// No description provided for @unitKilometers.
  ///
  /// In en, this message translates to:
  /// **'{value} km'**
  String unitKilometers(String value);

  /// No description provided for @unitKmh.
  ///
  /// In en, this message translates to:
  /// **'{value} km/h'**
  String unitKmh(String value);

  /// No description provided for @unitMph.
  ///
  /// In en, this message translates to:
  /// **'{value} mph'**
  String unitMph(String value);

  /// No description provided for @unitFeet.
  ///
  /// In en, this message translates to:
  /// **'{value} ft'**
  String unitFeet(String value);

  /// No description provided for @unitMiles.
  ///
  /// In en, this message translates to:
  /// **'{value} mi'**
  String unitMiles(String value);

  /// No description provided for @settingsAppearanceSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceSection;

  /// No description provided for @settingsThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeLabel;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsMeasurementSection.
  ///
  /// In en, this message translates to:
  /// **'Measurement'**
  String get settingsMeasurementSection;

  /// No description provided for @settingsUnitSystemLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit system'**
  String get settingsUnitSystemLabel;

  /// No description provided for @settingsUnitMetric.
  ///
  /// In en, this message translates to:
  /// **'Metric (km, m/s → km/h)'**
  String get settingsUnitMetric;

  /// No description provided for @settingsUnitImperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial (mi, m/s → mph)'**
  String get settingsUnitImperial;

  /// No description provided for @settingsTimeFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Lap time separator'**
  String get settingsTimeFormatLabel;

  /// No description provided for @settingsTimeFormatDot.
  ///
  /// In en, this message translates to:
  /// **'Dot  —  01:23.456'**
  String get settingsTimeFormatDot;

  /// No description provided for @settingsTimeFormatComma.
  ///
  /// In en, this message translates to:
  /// **'Comma  —  01:23,456'**
  String get settingsTimeFormatComma;

  /// No description provided for @settingsSessionSection.
  ///
  /// In en, this message translates to:
  /// **'Session behaviour'**
  String get settingsSessionSection;

  /// No description provided for @settingsKeepScreenAwakeLabel.
  ///
  /// In en, this message translates to:
  /// **'Keep screen awake'**
  String get settingsKeepScreenAwakeLabel;

  /// No description provided for @settingsKeepScreenAwakeDesc.
  ///
  /// In en, this message translates to:
  /// **'Prevents the display from sleeping during an active session or free ride.'**
  String get settingsKeepScreenAwakeDesc;

  /// No description provided for @settingsHapticFeedbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get settingsHapticFeedbackLabel;

  /// No description provided for @settingsHapticFeedbackDesc.
  ///
  /// In en, this message translates to:
  /// **'Vibrate when crossing a sector gate or the finish line.'**
  String get settingsHapticFeedbackDesc;

  /// No description provided for @settingsAudioAlertsLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio alerts'**
  String get settingsAudioAlertsLabel;

  /// No description provided for @settingsAudioAlertsDesc.
  ///
  /// In en, this message translates to:
  /// **'Play a short beep on each sector and lap crossing.'**
  String get settingsAudioAlertsDesc;

  /// No description provided for @settingsGpsSamplingLabel.
  ///
  /// In en, this message translates to:
  /// **'GPS update rate'**
  String get settingsGpsSamplingLabel;

  /// No description provided for @settingsGpsSampling1s.
  ///
  /// In en, this message translates to:
  /// **'Every 1 s — high accuracy, more battery'**
  String get settingsGpsSampling1s;

  /// No description provided for @settingsGpsSampling2s.
  ///
  /// In en, this message translates to:
  /// **'Every ~2 s — balanced'**
  String get settingsGpsSampling2s;

  /// No description provided for @settingsGpsSampling5s.
  ///
  /// In en, this message translates to:
  /// **'Every ~5 s — low battery'**
  String get settingsGpsSampling5s;

  /// No description provided for @settingsRoutesSection.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get settingsRoutesSection;

  /// No description provided for @settingsDefaultRoutingProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Default routing mode'**
  String get settingsDefaultRoutingProfileLabel;

  /// No description provided for @settingsRoutingProfileRoad.
  ///
  /// In en, this message translates to:
  /// **'Road'**
  String get settingsRoutingProfileRoad;

  /// No description provided for @settingsRoutingProfileTrail.
  ///
  /// In en, this message translates to:
  /// **'Trail'**
  String get settingsRoutingProfileTrail;

  /// No description provided for @settingsRoutingProfileCycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get settingsRoutingProfileCycling;

  /// No description provided for @settingsGarageSection.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get settingsGarageSection;

  /// No description provided for @settingsDefaultVehicleLabel.
  ///
  /// In en, this message translates to:
  /// **'Default vehicle'**
  String get settingsDefaultVehicleLabel;

  /// No description provided for @settingsDefaultVehicleNone.
  ///
  /// In en, this message translates to:
  /// **'None (always ask)'**
  String get settingsDefaultVehicleNone;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// No description provided for @settingsChangePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePasswordLabel;

  /// No description provided for @settingsDeleteAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccountLabel;

  /// No description provided for @settingsDeleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get settingsDeleteAccountConfirmTitle;

  /// No description provided for @settingsDeleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'All your data will be permanently deleted. This cannot be undone.'**
  String get settingsDeleteAccountConfirmBody;

  /// No description provided for @settingsDeleteAccountConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get settingsDeleteAccountConfirmButton;

  /// No description provided for @settingsDeleteAccountSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account deleted. Goodbye!'**
  String get settingsDeleteAccountSuccess;

  /// No description provided for @settingsDeleteAccountError.
  ///
  /// In en, this message translates to:
  /// **'Could not delete account. Try again.'**
  String get settingsDeleteAccountError;

  /// No description provided for @settingsChangePasswordCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get settingsChangePasswordCurrentLabel;

  /// No description provided for @settingsChangePasswordNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get settingsChangePasswordNewLabel;

  /// No description provided for @settingsChangePasswordConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get settingsChangePasswordConfirmLabel;

  /// No description provided for @settingsChangePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get settingsChangePasswordButton;

  /// No description provided for @settingsChangePasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get settingsChangePasswordSuccess;

  /// No description provided for @settingsChangePasswordError.
  ///
  /// In en, this message translates to:
  /// **'Could not update password. Try again.'**
  String get settingsChangePasswordError;

  /// No description provided for @settingsChangePasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get settingsChangePasswordMismatch;

  /// No description provided for @settingsChangePasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Minimum 6 characters'**
  String get settingsChangePasswordTooShort;

  /// No description provided for @settingsDataSection.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsDataSection;

  /// No description provided for @settingsExportHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Export history'**
  String get settingsExportHistoryLabel;

  /// No description provided for @settingsExportHistoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Download all sessions and free rides as a CSV file.'**
  String get settingsExportHistoryDesc;

  /// No description provided for @settingsClearCacheLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear local data'**
  String get settingsClearCacheLabel;

  /// No description provided for @settingsClearCacheDesc.
  ///
  /// In en, this message translates to:
  /// **'Deletes all locally saved routes and sessions. Cloud data is not affected.'**
  String get settingsClearCacheDesc;

  /// No description provided for @settingsClearCacheConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all local data?'**
  String get settingsClearCacheConfirmTitle;

  /// No description provided for @settingsClearCacheConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your routes and sessions will be deleted from this device. If sync is enabled they will remain in the cloud.'**
  String get settingsClearCacheConfirmBody;

  /// No description provided for @settingsClearCacheConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Clear data'**
  String get settingsClearCacheConfirmButton;

  /// No description provided for @settingsClearCacheDone.
  ///
  /// In en, this message translates to:
  /// **'Local data cleared'**
  String get settingsClearCacheDone;

  /// No description provided for @settingsExportSharing.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get settingsExportSharing;

  /// No description provided for @settingsDiagnosticsSection.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnosticsSection;

  /// No description provided for @settingsDiagnosticsLogsLabel.
  ///
  /// In en, this message translates to:
  /// **'View logs'**
  String get settingsDiagnosticsLogsLabel;

  /// No description provided for @settingsDiagnosticsLogsDesc.
  ///
  /// In en, this message translates to:
  /// **'Errors and warnings from Mapbox, Supabase and the app'**
  String get settingsDiagnosticsLogsDesc;

  /// No description provided for @settingsDiagnosticsRemoteLogsLabel.
  ///
  /// In en, this message translates to:
  /// **'Upload logs to server'**
  String get settingsDiagnosticsRemoteLogsLabel;

  /// No description provided for @settingsDiagnosticsRemoteLogsDesc.
  ///
  /// In en, this message translates to:
  /// **'Allows reviewing logs from the Supabase dashboard'**
  String get settingsDiagnosticsRemoteLogsDesc;

  /// No description provided for @logsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get logsScreenTitle;

  /// No description provided for @logsUploadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Upload now'**
  String get logsUploadTooltip;

  /// No description provided for @logsShareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share all'**
  String get logsShareTooltip;

  /// No description provided for @logsClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get logsClearTooltip;

  /// No description provided for @logsClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all logs?'**
  String get logsClearConfirmTitle;

  /// No description provided for @logsClearConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get logsClearConfirmBody;

  /// No description provided for @logsClearConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get logsClearConfirmButton;

  /// No description provided for @logsPending.
  ///
  /// In en, this message translates to:
  /// **'{count} pending upload'**
  String logsPending(int count);

  /// No description provided for @logsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get logsEmpty;

  /// No description provided for @logsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get logsSearchHint;

  /// No description provided for @logsCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get logsCopiedToClipboard;

  /// No description provided for @mapNoRoute.
  ///
  /// In en, this message translates to:
  /// **'No route'**
  String get mapNoRoute;

  /// No description provided for @historyBestLapSuffix.
  ///
  /// In en, this message translates to:
  /// **' · best {duration}'**
  String historyBestLapSuffix(String duration);

  /// No description provided for @navFreeRide.
  ///
  /// In en, this message translates to:
  /// **'Free ride'**
  String get navFreeRide;

  /// No description provided for @freeRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Free ride'**
  String get freeRideTitle;

  /// No description provided for @freeRideIdleTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride without a destination'**
  String get freeRideIdleTitle;

  /// No description provided for @freeRideIdleMessage.
  ///
  /// In en, this message translates to:
  /// **'Record your path in real time without a predefined route. Speed, distance and position are tracked automatically.'**
  String get freeRideIdleMessage;

  /// No description provided for @freeRideStartButton.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get freeRideStartButton;

  /// No description provided for @freeRideSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'New recording'**
  String get freeRideSetupTitle;

  /// No description provided for @freeRideSetupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get freeRideSetupNameLabel;

  /// No description provided for @freeRideElapsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Elapsed'**
  String get freeRideElapsedLabel;

  /// No description provided for @freeRideDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get freeRideDistanceLabel;

  /// No description provided for @freeRideSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get freeRideSpeedLabel;

  /// No description provided for @freeRideMaxSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Max speed'**
  String get freeRideMaxSpeedLabel;

  /// No description provided for @freeRideAvgSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Avg speed'**
  String get freeRideAvgSpeedLabel;

  /// No description provided for @freeRideFinishButton.
  ///
  /// In en, this message translates to:
  /// **'Finish ride'**
  String get freeRideFinishButton;

  /// No description provided for @freeRideCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride complete'**
  String get freeRideCompleteTitle;

  /// No description provided for @freeRideSavedSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Free ride saved'**
  String get freeRideSavedSnackBar;

  /// No description provided for @freeRideSaveAsRouteButton.
  ///
  /// In en, this message translates to:
  /// **'Save as reusable route'**
  String get freeRideSaveAsRouteButton;

  /// No description provided for @freeRideDiscardButton.
  ///
  /// In en, this message translates to:
  /// **'Finish without saving route'**
  String get freeRideDiscardButton;

  /// No description provided for @freeRideNewRideButton.
  ///
  /// In en, this message translates to:
  /// **'New ride'**
  String get freeRideNewRideButton;

  /// No description provided for @freeRideSaveRouteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save as route'**
  String get freeRideSaveRouteDialogTitle;

  /// No description provided for @freeRideNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get freeRideNameLabel;

  /// No description provided for @freeRideDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get freeRideDescriptionLabel;

  /// No description provided for @freeRideDifficultyLabel.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get freeRideDifficultyLabel;

  /// No description provided for @freeRideRouteSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'Route \"{name}\" saved'**
  String freeRideRouteSavedSnack(String name);

  /// No description provided for @freeRidePointsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 point} other{{count} points}}'**
  String freeRidePointsLabel(int count);

  /// No description provided for @historyNoEntriesTitle.
  ///
  /// In en, this message translates to:
  /// **'No activity recorded yet'**
  String get historyNoEntriesTitle;

  /// No description provided for @historyNoEntriesMessage.
  ///
  /// In en, this message translates to:
  /// **'Go for a free ride or record a session on a route.'**
  String get historyNoEntriesMessage;

  /// No description provided for @historyFreeRideLabel.
  ///
  /// In en, this message translates to:
  /// **'Free ride'**
  String get historyFreeRideLabel;

  /// No description provided for @historyFreeRideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{date} · {distance}'**
  String historyFreeRideSubtitle(String date, String distance);

  /// No description provided for @historyDeleteFreeRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete free ride'**
  String get historyDeleteFreeRideTitle;

  /// No description provided for @historyFreeRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Free ride detail'**
  String get historyFreeRideTitle;

  /// No description provided for @historyRenameFreeRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename ride'**
  String get historyRenameFreeRideTitle;

  /// No description provided for @historyRenameFreeRideLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get historyRenameFreeRideLabel;

  /// No description provided for @historyRenamedSnack.
  ///
  /// In en, this message translates to:
  /// **'Name updated'**
  String get historyRenamedSnack;

  /// No description provided for @historyRenameRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename route'**
  String get historyRenameRouteTitle;

  /// No description provided for @historyRenameRouteLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get historyRenameRouteLabel;

  /// No description provided for @historySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get historySearchHint;

  /// No description provided for @historyFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get historyFiltersTitle;

  /// No description provided for @historyFiltersOpen.
  ///
  /// In en, this message translates to:
  /// **'Open filters'**
  String get historyFiltersOpen;

  /// No description provided for @historyFiltersApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get historyFiltersApply;

  /// No description provided for @historyFiltersClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get historyFiltersClear;

  /// No description provided for @historyFilterKindLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get historyFilterKindLabel;

  /// No description provided for @historyFilterKindSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get historyFilterKindSession;

  /// No description provided for @historyFilterKindFreeRide.
  ///
  /// In en, this message translates to:
  /// **'Free ride'**
  String get historyFilterKindFreeRide;

  /// No description provided for @historyFilterVehicleLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get historyFilterVehicleLabel;

  /// No description provided for @historyNoVehicle.
  ///
  /// In en, this message translates to:
  /// **'No vehicle'**
  String get historyNoVehicle;

  /// No description provided for @historyFilterDateRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get historyFilterDateRangeLabel;

  /// No description provided for @historyDateLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get historyDateLast7Days;

  /// No description provided for @historyDateLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get historyDateLast30Days;

  /// No description provided for @historyDateThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get historyDateThisYear;

  /// No description provided for @historyDateCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get historyDateCustom;

  /// No description provided for @historyFilterMinDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Min distance'**
  String get historyFilterMinDistanceLabel;

  /// No description provided for @historyFilterMinDistanceChip.
  ///
  /// In en, this message translates to:
  /// **'≥ {value}'**
  String historyFilterMinDistanceChip(String value);

  /// No description provided for @historyFilterVehicleChipMany.
  ///
  /// In en, this message translates to:
  /// **'Vehicles ({count})'**
  String historyFilterVehicleChipMany(int count);

  /// No description provided for @historyFilteredEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get historyFilteredEmptyTitle;

  /// No description provided for @historyFilteredEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get historyFilteredEmptyAction;

  /// No description provided for @historyFilterGroupByRoute.
  ///
  /// In en, this message translates to:
  /// **'Group by route'**
  String get historyFilterGroupByRoute;

  /// No description provided for @historyGroupFreeRides.
  ///
  /// In en, this message translates to:
  /// **'Free rides'**
  String get historyGroupFreeRides;

  /// No description provided for @historyGroupChip.
  ///
  /// In en, this message translates to:
  /// **'Grouped by route'**
  String get historyGroupChip;

  /// No description provided for @historyGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}} · last {date}'**
  String historyGroupSubtitle(int count, String date);

  /// No description provided for @routesTitle.
  ///
  /// In en, this message translates to:
  /// **'My routes'**
  String get routesTitle;

  /// No description provided for @routesViewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get routesViewList;

  /// No description provided for @routesViewGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get routesViewGrid;

  /// No description provided for @routesSessionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No sessions} =1{1 session} other{{count} sessions}}'**
  String routesSessionsCount(int count);

  /// No description provided for @routesBestLap.
  ///
  /// In en, this message translates to:
  /// **'Best: {time}'**
  String routesBestLap(String time);

  /// No description provided for @routesDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Route detail'**
  String get routesDetailTitle;

  /// No description provided for @navGarage.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get navGarage;

  /// No description provided for @garageTitle.
  ///
  /// In en, this message translates to:
  /// **'My garage'**
  String get garageTitle;

  /// No description provided for @garageNoVehiclesTitle.
  ///
  /// In en, this message translates to:
  /// **'No vehicles yet'**
  String get garageNoVehiclesTitle;

  /// No description provided for @garageNoVehiclesMessage.
  ///
  /// In en, this message translates to:
  /// **'Add your first car, bike, or kart to track which vehicle you use on each session.'**
  String get garageNoVehiclesMessage;

  /// No description provided for @garageAddVehicleButton.
  ///
  /// In en, this message translates to:
  /// **'Add vehicle'**
  String get garageAddVehicleButton;

  /// No description provided for @garageViewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get garageViewList;

  /// No description provided for @garageViewGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get garageViewGrid;

  /// No description provided for @garageDeleteVehicleTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete vehicle'**
  String get garageDeleteVehicleTitle;

  /// No description provided for @garageDeleteVehicleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{vehicleName}\"? This cannot be undone.'**
  String garageDeleteVehicleConfirm(String vehicleName);

  /// No description provided for @garageVehicleSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'Vehicle saved'**
  String get garageVehicleSavedSnack;

  /// No description provided for @garageVehicleDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Vehicle deleted'**
  String get garageVehicleDeletedSnack;

  /// No description provided for @garagePhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get garagePhotoUpdated;

  /// No description provided for @garageErrorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get garageErrorUnexpected;

  /// No description provided for @garageChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get garageChangePhoto;

  /// No description provided for @vehicleFormTitleNew.
  ///
  /// In en, this message translates to:
  /// **'New vehicle'**
  String get vehicleFormTitleNew;

  /// No description provided for @vehicleFormTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit vehicle'**
  String get vehicleFormTitleEdit;

  /// No description provided for @vehicleFormNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get vehicleFormNameLabel;

  /// No description provided for @vehicleFormNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get vehicleFormNameRequired;

  /// No description provided for @vehicleFormNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum 2 characters'**
  String get vehicleFormNameMinLength;

  /// No description provided for @vehicleFormTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get vehicleFormTypeLabel;

  /// No description provided for @vehicleFormModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model (optional)'**
  String get vehicleFormModelLabel;

  /// No description provided for @vehicleFormYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year (optional)'**
  String get vehicleFormYearLabel;

  /// No description provided for @vehicleFormHorsepowerLabel.
  ///
  /// In en, this message translates to:
  /// **'Horsepower (optional)'**
  String get vehicleFormHorsepowerLabel;

  /// No description provided for @vehicleFormTorqueLabel.
  ///
  /// In en, this message translates to:
  /// **'Torque Nm (optional)'**
  String get vehicleFormTorqueLabel;

  /// No description provided for @vehicleFormWeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight kg (optional)'**
  String get vehicleFormWeightLabel;

  /// No description provided for @vehicleFormDrivetrainLabel.
  ///
  /// In en, this message translates to:
  /// **'Drivetrain (optional)'**
  String get vehicleFormDrivetrainLabel;

  /// No description provided for @vehicleFormNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get vehicleFormNotesLabel;

  /// No description provided for @vehicleFormNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Tire setup, modifications, etc.'**
  String get vehicleFormNotesHint;

  /// No description provided for @vehicleFormSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get vehicleFormSaveButton;

  /// No description provided for @vehicleTypeCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get vehicleTypeCar;

  /// No description provided for @vehicleTypeMotorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get vehicleTypeMotorcycle;

  /// No description provided for @vehicleTypeBicycle.
  ///
  /// In en, this message translates to:
  /// **'Bicycle'**
  String get vehicleTypeBicycle;

  /// No description provided for @vehicleTypeGoKart.
  ///
  /// In en, this message translates to:
  /// **'Go-kart'**
  String get vehicleTypeGoKart;

  /// No description provided for @vehicleTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get vehicleTypeOther;

  /// No description provided for @drivetrainFront.
  ///
  /// In en, this message translates to:
  /// **'Front-wheel drive'**
  String get drivetrainFront;

  /// No description provided for @drivetrainRear.
  ///
  /// In en, this message translates to:
  /// **'Rear-wheel drive'**
  String get drivetrainRear;

  /// No description provided for @drivetrainAllWheel.
  ///
  /// In en, this message translates to:
  /// **'All-wheel drive'**
  String get drivetrainAllWheel;

  /// No description provided for @vehicleDetailSpecs.
  ///
  /// In en, this message translates to:
  /// **'Specs'**
  String get vehicleDetailSpecs;

  /// No description provided for @vehicleDetailHorsepower.
  ///
  /// In en, this message translates to:
  /// **'{hp} hp'**
  String vehicleDetailHorsepower(int hp);

  /// No description provided for @vehicleDetailTorque.
  ///
  /// In en, this message translates to:
  /// **'{nm} Nm'**
  String vehicleDetailTorque(int nm);

  /// No description provided for @vehicleDetailWeight.
  ///
  /// In en, this message translates to:
  /// **'{kg} kg'**
  String vehicleDetailWeight(int kg);

  /// No description provided for @vehiclePickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehiclePickerLabel;

  /// No description provided for @vehiclePickerOnFoot.
  ///
  /// In en, this message translates to:
  /// **'On foot'**
  String get vehiclePickerOnFoot;

  /// No description provided for @vehiclePickerSelectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Select a vehicle'**
  String get vehiclePickerSelectVehicle;

  /// No description provided for @elevationRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get elevationRangeLabel;

  /// No description provided for @routeExpectedTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Normal time'**
  String get routeExpectedTimeLabel;

  /// No description provided for @elevationRangeValue.
  ///
  /// In en, this message translates to:
  /// **'{value} m'**
  String elevationRangeValue(String value);

  /// No description provided for @elevationRangeValueFeet.
  ///
  /// In en, this message translates to:
  /// **'{value} ft'**
  String elevationRangeValueFeet(String value);

  /// No description provided for @backgroundNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Splitway · Recording route'**
  String get backgroundNotificationTitle;

  /// No description provided for @backgroundDeniedBanner.
  ///
  /// In en, this message translates to:
  /// **'Recording will stop if you leave the app. Grant \"Always\" location permission for background recording.'**
  String get backgroundDeniedBanner;

  /// No description provided for @backgroundOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get backgroundOpenSettings;

  /// No description provided for @backgroundDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Background recording'**
  String get backgroundDialogTitle;

  /// No description provided for @backgroundDialogBody.
  ///
  /// In en, this message translates to:
  /// **'To keep recording your route when the screen is off or you switch apps, you need to allow location access \"Always\".\n\nGo to Settings > Permissions > Location and select \"Allow always\".'**
  String get backgroundDialogBody;

  /// No description provided for @backgroundDialogOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get backgroundDialogOpenSettings;

  /// No description provided for @backgroundDialogSkip.
  ///
  /// In en, this message translates to:
  /// **'Continue without background'**
  String get backgroundDialogSkip;

  /// No description provided for @notificationDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get notificationDialogTitle;

  /// No description provided for @notificationDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Splitway uses notifications to keep you informed during route recording — showing elapsed time, distance, and tracking status even when the app is in the background.'**
  String get notificationDialogBody;

  /// No description provided for @notificationDialogAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get notificationDialogAllow;

  /// No description provided for @notificationDialogSkip.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notificationDialogSkip;

  /// No description provided for @mapStyleOutdoors.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get mapStyleOutdoors;

  /// No description provided for @mapStyleSatelliteStreets.
  ///
  /// In en, this message translates to:
  /// **'Satellite'**
  String get mapStyleSatelliteStreets;

  /// No description provided for @mapStyleDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get mapStyleDark;

  /// No description provided for @mapStyleLayersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Map style'**
  String get mapStyleLayersTooltip;

  /// No description provided for @heatmapToggleOn.
  ///
  /// In en, this message translates to:
  /// **'Show speed heatmap'**
  String get heatmapToggleOn;

  /// No description provided for @heatmapToggleOff.
  ///
  /// In en, this message translates to:
  /// **'Hide speed heatmap'**
  String get heatmapToggleOff;

  /// No description provided for @heatmapLegendTitle.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get heatmapLegendTitle;

  /// No description provided for @editorSearchLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Search location...'**
  String get editorSearchLocationHint;

  /// No description provided for @editorSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get editorSearchNoResults;

  /// No description provided for @navSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed test'**
  String get navSpeed;

  /// No description provided for @drawerSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed test'**
  String get drawerSpeed;

  /// No description provided for @speedSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Speed test'**
  String get speedSetupTitle;

  /// No description provided for @speedSetupVehicleSection.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get speedSetupVehicleSection;

  /// No description provided for @speedSetupVehicleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No vehicles in your garage yet'**
  String get speedSetupVehicleEmpty;

  /// No description provided for @speedSetupMetricsSection.
  ///
  /// In en, this message translates to:
  /// **'What to measure'**
  String get speedSetupMetricsSection;

  /// No description provided for @speedSetupCountdownSection.
  ///
  /// In en, this message translates to:
  /// **'Countdown'**
  String get speedSetupCountdownSection;

  /// No description provided for @speedSetupNameSection.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get speedSetupNameSection;

  /// No description provided for @speedSetupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for default'**
  String get speedSetupNameHint;

  /// No description provided for @speedSetupViewSection.
  ///
  /// In en, this message translates to:
  /// **'Results view'**
  String get speedSetupViewSection;

  /// No description provided for @speedSetupViewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get speedSetupViewList;

  /// No description provided for @speedSetupViewGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get speedSetupViewGrid;

  /// No description provided for @speedSetupContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get speedSetupContinue;

  /// No description provided for @speedSetupSecondsValue.
  ///
  /// In en, this message translates to:
  /// **'{n}s'**
  String speedSetupSecondsValue(int n);

  /// No description provided for @speedReadyMessage.
  ///
  /// In en, this message translates to:
  /// **'When you are ready, press Start'**
  String get speedReadyMessage;

  /// No description provided for @speedReadyStart.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get speedReadyStart;

  /// No description provided for @speedSessionGo.
  ///
  /// In en, this message translates to:
  /// **'GO!'**
  String get speedSessionGo;

  /// No description provided for @speedFinishedTitle.
  ///
  /// In en, this message translates to:
  /// **'Session complete'**
  String get speedFinishedTitle;

  /// No description provided for @speedFinishedSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get speedFinishedSave;

  /// No description provided for @speedFinishedDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get speedFinishedDiscard;

  /// No description provided for @speedFinishedManualStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get speedFinishedManualStop;

  /// No description provided for @speedFalseStartTitle.
  ///
  /// In en, this message translates to:
  /// **'FALSE START'**
  String get speedFalseStartTitle;

  /// No description provided for @speedFalseStartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You moved before the final beep'**
  String get speedFalseStartSubtitle;

  /// No description provided for @speedFalseStartRetry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get speedFalseStartRetry;

  /// No description provided for @speedFalseStartCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get speedFalseStartCancel;

  /// No description provided for @speedCategoryDrag.
  ///
  /// In en, this message translates to:
  /// **'Drag'**
  String get speedCategoryDrag;

  /// No description provided for @speedCategoryStopwatch.
  ///
  /// In en, this message translates to:
  /// **'Stopwatch'**
  String get speedCategoryStopwatch;

  /// No description provided for @speedCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get speedCategoryOther;

  /// No description provided for @speedMetricReactionTime.
  ///
  /// In en, this message translates to:
  /// **'Reaction time'**
  String get speedMetricReactionTime;

  /// No description provided for @speedMetricSixtyFoot.
  ///
  /// In en, this message translates to:
  /// **'60 ft'**
  String get speedMetricSixtyFoot;

  /// No description provided for @speedMetricEighthMile.
  ///
  /// In en, this message translates to:
  /// **'1/8 mile'**
  String get speedMetricEighthMile;

  /// No description provided for @speedMetricQuarterMile.
  ///
  /// In en, this message translates to:
  /// **'1/4 mile'**
  String get speedMetricQuarterMile;

  /// No description provided for @speedMetricZeroTo50.
  ///
  /// In en, this message translates to:
  /// **'0-50'**
  String get speedMetricZeroTo50;

  /// No description provided for @speedMetricZeroTo100.
  ///
  /// In en, this message translates to:
  /// **'0-100'**
  String get speedMetricZeroTo100;

  /// No description provided for @speedMetricZeroTo200.
  ///
  /// In en, this message translates to:
  /// **'0-200'**
  String get speedMetricZeroTo200;

  /// No description provided for @speedMetricTopSpeed.
  ///
  /// In en, this message translates to:
  /// **'Top speed'**
  String get speedMetricTopSpeed;

  /// No description provided for @speedHistoryTab.
  ///
  /// In en, this message translates to:
  /// **'Speed test'**
  String get speedHistoryTab;

  /// No description provided for @speedHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No speed sessions yet'**
  String get speedHistoryEmpty;

  /// No description provided for @speedHistoryDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get speedHistoryDeleteTooltip;

  /// No description provided for @speedHistoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get speedHistoryDeleteTitle;

  /// No description provided for @speedHistoryDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String speedHistoryDeleteConfirm(String name);

  /// No description provided for @speedDetailEditNameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get speedDetailEditNameTooltip;

  /// No description provided for @speedDetailEditNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get speedDetailEditNameTitle;

  /// No description provided for @speedDetailEditNameHint.
  ///
  /// In en, this message translates to:
  /// **'Session name'**
  String get speedDetailEditNameHint;

  /// No description provided for @speedDetailEditNameSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get speedDetailEditNameSave;

  /// No description provided for @speedDetailEditNameCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get speedDetailEditNameCancel;

  /// No description provided for @speedDetailEditNameError.
  ///
  /// In en, this message translates to:
  /// **'Could not save name'**
  String get speedDetailEditNameError;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @statsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get statsEmptyTitle;

  /// No description provided for @statsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Record a session, free ride, or speed test to see your statistics here.'**
  String get statsEmptyMessage;

  /// No description provided for @statsOverviewSection.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get statsOverviewSection;

  /// No description provided for @statsTotalSessions.
  ///
  /// In en, this message translates to:
  /// **'Total activities'**
  String get statsTotalSessions;

  /// No description provided for @statsTotalDistance.
  ///
  /// In en, this message translates to:
  /// **'Total distance'**
  String get statsTotalDistance;

  /// No description provided for @statsTotalTime.
  ///
  /// In en, this message translates to:
  /// **'Total time'**
  String get statsTotalTime;

  /// No description provided for @statsVehiclesOwned.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get statsVehiclesOwned;

  /// No description provided for @statsPersonalBestsSection.
  ///
  /// In en, this message translates to:
  /// **'Personal bests'**
  String get statsPersonalBestsSection;

  /// No description provided for @statsRecordsSection.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get statsRecordsSection;

  /// No description provided for @statsTopSpeedRecord.
  ///
  /// In en, this message translates to:
  /// **'Top speed'**
  String get statsTopSpeedRecord;

  /// No description provided for @statsLongestRide.
  ///
  /// In en, this message translates to:
  /// **'Longest ride'**
  String get statsLongestRide;

  /// No description provided for @statsLongestSession.
  ///
  /// In en, this message translates to:
  /// **'Longest session'**
  String get statsLongestSession;

  /// No description provided for @statsActivitySection.
  ///
  /// In en, this message translates to:
  /// **'Last 8 weeks'**
  String get statsActivitySection;

  /// No description provided for @statsActivityWeekly.
  ///
  /// In en, this message translates to:
  /// **'Activities per week'**
  String get statsActivityWeekly;

  /// No description provided for @statsByVehicleSection.
  ///
  /// In en, this message translates to:
  /// **'By vehicle'**
  String get statsByVehicleSection;

  /// No description provided for @statsNoBestYet.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get statsNoBestYet;

  /// No description provided for @statsActivitiesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No activities} =1{1 activity} other{{count} activities}}'**
  String statsActivitiesCount(int count);

  /// No description provided for @statsBestQuarterMileShort.
  ///
  /// In en, this message translates to:
  /// **'Best 1/4 mi'**
  String get statsBestQuarterMileShort;

  /// No description provided for @statsNoSpeedSessionsForVehicle.
  ///
  /// In en, this message translates to:
  /// **'No speed tests'**
  String get statsNoSpeedSessionsForVehicle;

  /// No description provided for @statsUnknownVehicle.
  ///
  /// In en, this message translates to:
  /// **'Unknown vehicle'**
  String get statsUnknownVehicle;

  /// No description provided for @statsMetricSelectorLabel.
  ///
  /// In en, this message translates to:
  /// **'Metric:'**
  String get statsMetricSelectorLabel;

  /// No description provided for @recordingPauseButton.
  ///
  /// In en, this message translates to:
  /// **'Pause ride'**
  String get recordingPauseButton;

  /// No description provided for @recordingResumeButton.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get recordingResumeButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
