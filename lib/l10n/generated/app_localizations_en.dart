// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Rental';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get homeTitle => 'Home';

  @override
  String get phoneEntryHeadline => 'Enter your phone number';

  @override
  String get phoneEntryBody => 'We\'ll send you a 6-digit code by SMS.';

  @override
  String get phoneEntryFieldLabel => 'Phone number';

  @override
  String get phoneEntryFieldHint => '09XX XXX XXX';

  @override
  String get phoneEntrySendCode => 'Send code';

  @override
  String get phoneEntrySending => 'Sending the code…';

  @override
  String get phoneEntryEmpty => 'Enter your phone number.';

  @override
  String get errorInvalidPhone => 'Enter an Ethiopian mobile number.';

  @override
  String get errorTooManyAttemptsLater =>
      'Too many attempts. Please try again later.';

  @override
  String get errorSmsSendFailed =>
      'We couldn\'t send the SMS. Please try again.';

  @override
  String get errorNetwork =>
      'No connection. Check your internet and try again.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get otpTitle => 'Enter the code';

  @override
  String errorTooManyAttemptsMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Too many attempts. Try again in $minutes minutes.',
      one: 'Too many attempts. Try again in 1 minute.',
    );
    return '$_temp0';
  }

  @override
  String get otpFieldLabel => '6-digit code';

  @override
  String get otpVerify => 'Verify';

  @override
  String get otpVerifying => 'Checking the code…';

  @override
  String get otpCodeExpired => 'This code has expired.';

  @override
  String get otpSendNewCode => 'Send a new code';

  @override
  String get otpSendingNewCode => 'Sending a new code…';

  @override
  String get otpNewCodeSent => 'We sent you a new code.';

  @override
  String get otpWrongCode => 'Wrong code. Please try again.';

  @override
  String get otpExpiredOrUsed => 'This code has expired or was already used.';

  @override
  String get otpAttemptsExceeded => 'Too many wrong attempts.';

  @override
  String get accountUnavailableMessage =>
      'This account is unavailable. Please contact support.';

  @override
  String otpSentTo(String phone) {
    return 'We sent a 6-digit code to $phone.';
  }

  @override
  String otpExpiresIn(String time) {
    return 'Code expires in $time';
  }

  @override
  String otpWrongCodeAttemptsLeft(int attempts) {
    String _temp0 = intl.Intl.pluralLogic(
      attempts,
      locale: localeName,
      other: 'Wrong code. $attempts attempts left.',
      one: 'Wrong code. 1 attempt left.',
      zero: 'Wrong code. No attempts left.',
    );
    return '$_temp0';
  }

  @override
  String get splashLoading => 'Loading…';

  @override
  String get splashCantConnect =>
      'Can\'t connect to the server. Check your internet and try again.';

  @override
  String get splashRetry => 'Retry';

  @override
  String get homeMenuTooltip => 'More options';

  @override
  String get homeSignOut => 'Sign out';

  @override
  String get homeSignedInPlaceholder => 'You\'re signed in.';

  @override
  String get accountUnavailableBackToSignIn => 'Back to sign in';
}
