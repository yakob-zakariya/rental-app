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
  String get placeholderGoToHome => 'Go to home';

  @override
  String get placeholderBackToSignIn => 'Back to sign in';
}
