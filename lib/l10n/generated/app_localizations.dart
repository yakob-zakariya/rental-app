import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// App name, shown as the window/task title. Temporary until the brand name is chosen.
  ///
  /// In en, this message translates to:
  /// **'Rental'**
  String get appTitle;

  /// Title of the sign-in (phone entry) screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// Title of the home screen.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// Headline on the phone entry screen.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get phoneEntryHeadline;

  /// Explains what happens after tapping 'Send code'.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send you a 6-digit code by SMS.'**
  String get phoneEntryBody;

  /// Label of the phone number field.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneEntryFieldLabel;

  /// Pattern shown in the empty phone field (not a real number).
  ///
  /// In en, this message translates to:
  /// **'09XX XXX XXX'**
  String get phoneEntryFieldHint;

  /// Button that asks the API to send the SMS code.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get phoneEntrySendCode;

  /// Screen-reader label of the spinner while the code is being requested.
  ///
  /// In en, this message translates to:
  /// **'Sending the code…'**
  String get phoneEntrySending;

  /// Error under the field when it is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number.'**
  String get phoneEntryEmpty;

  /// Error when the API rejects the phone number (INVALID_PHONE).
  ///
  /// In en, this message translates to:
  /// **'Enter an Ethiopian mobile number.'**
  String get errorInvalidPhone;

  /// Rate-limit error when no waiting time is known.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get errorTooManyAttemptsLater;

  /// Error when the SMS could not be sent (SMS_SEND_FAILED).
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t send the SMS. Please try again.'**
  String get errorSmsSendFailed;

  /// Error when the server can't be reached (no connection or timeout).
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get errorNetwork;

  /// Fallback error for unexpected or unknown errors.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// Title of the SMS code screen.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get otpTitle;

  /// Rate-limit error with the waiting time, rounded up to whole minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{Too many attempts. Try again in 1 minute.} other{Too many attempts. Try again in {minutes} minutes.}}'**
  String errorTooManyAttemptsMinutes(int minutes);

  /// Label of the SMS code field.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get otpFieldLabel;

  /// Button that checks the SMS code.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerify;

  /// Screen-reader label of the spinner while the code is checked.
  ///
  /// In en, this message translates to:
  /// **'Checking the code…'**
  String get otpVerifying;

  /// Shown when the countdown reaches zero.
  ///
  /// In en, this message translates to:
  /// **'This code has expired.'**
  String get otpCodeExpired;

  /// Button that requests a new SMS code.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get otpSendNewCode;

  /// Screen-reader label of the spinner while a new code is requested.
  ///
  /// In en, this message translates to:
  /// **'Sending a new code…'**
  String get otpSendingNewCode;

  /// Confirmation after a new code was requested.
  ///
  /// In en, this message translates to:
  /// **'We sent you a new code.'**
  String get otpNewCodeSent;

  /// OTP_INVALID without a number of attempts left.
  ///
  /// In en, this message translates to:
  /// **'Wrong code. Please try again.'**
  String get otpWrongCode;

  /// OTP_EXPIRED.
  ///
  /// In en, this message translates to:
  /// **'This code has expired or was already used.'**
  String get otpExpiredOrUsed;

  /// OTP_ATTEMPTS_EXCEEDED: the user must ask for a new code.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong attempts.'**
  String get otpAttemptsExceeded;

  /// Neutral message for an unavailable (blocked) account. Never give a reason.
  ///
  /// In en, this message translates to:
  /// **'This account is unavailable. Please contact support.'**
  String get accountUnavailableMessage;

  /// Under the code screen's title. {phone} is the number as the user typed it.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {phone}.'**
  String otpSentTo(String phone);

  /// Countdown on the code screen. {time} is minutes:seconds, e.g. 4:59.
  ///
  /// In en, this message translates to:
  /// **'Code expires in {time}'**
  String otpExpiresIn(String time);

  /// OTP_INVALID with the number of attempts left.
  ///
  /// In en, this message translates to:
  /// **'{attempts, plural, =0{Wrong code. No attempts left.} =1{Wrong code. 1 attempt left.} other{Wrong code. {attempts} attempts left.}}'**
  String otpWrongCodeAttemptsLeft(int attempts);

  /// Screen-reader label of the spinner on the startup screen.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get splashLoading;

  /// Startup screen when the server can't be reached. The user stays signed in.
  ///
  /// In en, this message translates to:
  /// **'Can\'t connect to the server. Check your internet and try again.'**
  String get splashCantConnect;

  /// Button on the startup screen that checks the connection again.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get splashRetry;

  /// Tooltip / screen-reader label of the home screen's menu button.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get homeMenuTooltip;

  /// Menu item that signs the user out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get homeSignOut;

  /// Only button on the account-unavailable screen.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get accountUnavailableBackToSignIn;

  /// Button that tries loading again after an error.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Screen-reader label of the spinner while the status loads.
  ///
  /// In en, this message translates to:
  /// **'Loading your verification status…'**
  String get homeLoadingStatus;

  /// Card title when the user hasn't verified yet.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity'**
  String get verifyNotVerifiedTitle;

  /// Why we verify (card body for not_verified).
  ///
  /// In en, this message translates to:
  /// **'Everyone here is verified, so landlords and tenants know who they\'re dealing with: no brokers, no fake accounts. It takes a few minutes with your Fayda ID card or passport.'**
  String get verifyNotVerifiedBody;

  /// Starts identity verification.
  ///
  /// In en, this message translates to:
  /// **'Verify my identity'**
  String get verifyNotVerifiedButton;

  /// Card title while the verification result is pending.
  ///
  /// In en, this message translates to:
  /// **'Checking your verification…'**
  String get verifyPendingTitle;

  /// Card body for pending.
  ///
  /// In en, this message translates to:
  /// **'This usually takes a few minutes.'**
  String get verifyPendingBody;

  /// Resumes an unfinished verification session.
  ///
  /// In en, this message translates to:
  /// **'Continue verification'**
  String get verifyContinueButton;

  /// Badge/title when the identity is verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verifyApprovedTitle;

  /// Card body for approved when the name isn't loaded.
  ///
  /// In en, this message translates to:
  /// **'Your identity is verified.'**
  String get verifyApprovedBody;

  /// Card title for declined.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t verify your identity'**
  String get verifyDeclinedTitle;

  /// Starts a new verification after a decline.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get verifyTryAgainButton;

  /// Declined and out of tries, with no known time.
  ///
  /// In en, this message translates to:
  /// **'You can try again later.'**
  String get verifyTryAgainLater;

  /// Asks the team to review the declined verification by hand.
  ///
  /// In en, this message translates to:
  /// **'Request manual review'**
  String get verifyManualReviewButton;

  /// Card title for manual_review.
  ///
  /// In en, this message translates to:
  /// **'Our team is reviewing your verification'**
  String get verifyManualReviewTitle;

  /// Card body for manual_review.
  ///
  /// In en, this message translates to:
  /// **'Check back here later.'**
  String get verifyManualReviewBody;

  /// The only text for a blocked user. Never give a reason.
  ///
  /// In en, this message translates to:
  /// **'Please contact support.'**
  String get verifyBlockedBody;

  /// Fallback for a status this app version doesn't know.
  ///
  /// In en, this message translates to:
  /// **'We can\'t show your verification status right now.'**
  String get verifyUnknownBody;

  /// Decline reason PHOTO_UNCLEAR.
  ///
  /// In en, this message translates to:
  /// **'The photo wasn\'t clear enough. Retake it in good light.'**
  String get reasonPhotoUnclear;

  /// Decline reason DOCUMENT_EXPIRED.
  ///
  /// In en, this message translates to:
  /// **'Your document has expired.'**
  String get reasonDocumentExpired;

  /// Decline reason DOCUMENT_NOT_ACCEPTED.
  ///
  /// In en, this message translates to:
  /// **'Use your Fayda ID card or a passport.'**
  String get reasonDocumentNotAccepted;

  /// Decline reason UNDERAGE.
  ///
  /// In en, this message translates to:
  /// **'You must be 18 or older.'**
  String get reasonUnderage;

  /// Decline reason DOCUMENT_NOT_VERIFIED.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t verify your document. Please try again.'**
  String get reasonDocumentNotVerified;

  /// Fallback for a decline reason this app version doesn't know.
  ///
  /// In en, this message translates to:
  /// **'Something didn\'t match. Please try again.'**
  String get reasonFallback;

  /// Approved card body with the verified name from GET /me.
  ///
  /// In en, this message translates to:
  /// **'Verified as {name}'**
  String verifyApprovedAs(String name);

  /// Declined and out of tries; {time} is today, 24-hour Addis Ababa time.
  ///
  /// In en, this message translates to:
  /// **'You can try again after {time}.'**
  String verifyRetryAfter(String time);

  /// Declined and out of tries; {time} is tomorrow, 24-hour Addis Ababa time.
  ///
  /// In en, this message translates to:
  /// **'You can try again tomorrow after {time}.'**
  String verifyRetryTomorrowAfter(String time);

  /// SnackBar when reloading the status fails for lack of connection; the last status stays on screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh. Check your connection.'**
  String get homeRefreshFailedOffline;

  /// Title of the consent screen shown before a new verification.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get consentTitle;

  /// Headline of the consent screen.
  ///
  /// In en, this message translates to:
  /// **'We\'ll check your ID and a selfie'**
  String get consentHeadline;

  /// Consent text. Must stay exactly true to what rental-api stores; legal review before launch.
  ///
  /// In en, this message translates to:
  /// **'Your ID and selfie are checked by our verification partner, Didit. We don\'t store the photos. We keep your verified name, date of birth and a protected one-way reference to your ID number, used only to prevent duplicate and banned accounts.'**
  String get consentBody;

  /// Starts the verification after reading the consent text.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get consentContinue;

  /// Screen-reader label of the spinner while the session starts.
  ///
  /// In en, this message translates to:
  /// **'Starting verification…'**
  String get consentStarting;

  /// Shown when the Didit flow failed.
  ///
  /// In en, this message translates to:
  /// **'Verification couldn\'t continue. Please try again.'**
  String get verifyFailedMessage;

  /// VERIFICATION_PROVIDER_UNAVAILABLE.
  ///
  /// In en, this message translates to:
  /// **'Verification is unavailable right now. Please try again shortly.'**
  String get verifyProviderUnavailable;

  /// Screen-reader label of a button's spinner on the status card.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get verifyBusy;

  /// App-bar title of the checking screen.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get checkingTitle;

  /// Shown on the checking screen after the first minute.
  ///
  /// In en, this message translates to:
  /// **'This can take a few minutes. You can leave this screen; Home will update when you come back.'**
  String get checkingLeaveHint;

  /// Shown on the checking screen when a poll fails for lack of connection.
  ///
  /// In en, this message translates to:
  /// **'No connection. We\'ll keep checking.'**
  String get checkingOfflineHint;

  /// Shown on the checking screen when a poll fails for another reason.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. We\'ll keep checking.'**
  String get checkingErrorHint;

  /// Leaves the checking screen.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get checkingBackHome;

  /// Title of the manual-review confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Request a manual review?'**
  String get manualReviewDialogTitle;

  /// Body of the manual-review confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Our team will look at your verification by hand. You\'ll see the result here.'**
  String get manualReviewDialogBody;

  /// Closes the manual-review dialog without requesting.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get manualReviewDialogCancel;

  /// Confirms the manual review request.
  ///
  /// In en, this message translates to:
  /// **'Request review'**
  String get manualReviewDialogConfirm;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
