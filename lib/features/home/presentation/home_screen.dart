import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Placeholder home screen (A2). A9 adds the verification status cards (from
/// `features/verification/`); later phases turn home into the listings feed.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: Center(
        child: OutlinedButton(
          onPressed: () => context.go(AppRoutes.signIn),
          child: Text(l10n.placeholderBackToSignIn),
        ),
      ),
    );
  }
}
