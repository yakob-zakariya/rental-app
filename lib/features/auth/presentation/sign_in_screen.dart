import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/config/app_config_provider.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Placeholder sign-in screen (A2). The real phone-entry screen comes in A6.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.signInTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: Text(l10n.placeholderGoToHome),
              ),
              // Debug builds only: lets you check which backend this build uses.
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                Text(ref.watch(appConfigProvider).apiBaseUrl.toString()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
