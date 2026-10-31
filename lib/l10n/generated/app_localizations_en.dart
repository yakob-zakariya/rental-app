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
  String get placeholderBackToSignIn => 'Back to sign in';

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
  String otpPlaceholderSentTo(String phone) {
    return 'We sent a code to $phone.';
  }
}
