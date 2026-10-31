import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

/// What the phone entry screen hands to the code screen.
class OtpScreenArgs {
  const OtpScreenArgs({required this.phone, required this.expiresInSeconds});

  /// The number as the user typed it (sent again with the code).
  final String phone;

  /// How long the code stays valid (for the countdown).
  final int expiresInSeconds;
}

/// Placeholder code screen (A6). A7 builds the real 6-digit entry, countdown
/// and sign-in.
class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key, required this.args});

  final OtpScreenArgs args;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.otpTitle)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          l10n.otpPlaceholderSentTo(args.phone),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
