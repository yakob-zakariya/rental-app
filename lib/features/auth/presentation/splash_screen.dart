import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'auth_controller.dart';

/// Shown at startup while the stored tokens are checked (spec 3.1). If the
/// check can't finish, it offers "Retry" — the user is never signed out for
/// that.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final error = ref.watch(authControllerProvider).startupError;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (error == null)
                    Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: l10n.splashLoading,
                      ),
                    )
                  else ...[
                    Icon(
                      error == StartupError.network
                          ? Icons.cloud_off_outlined
                          : Icons.error_outline,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      error == StartupError.network
                          ? l10n.splashCantConnect
                          : l10n.errorGeneric,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: () => ref
                          .read(authControllerProvider.notifier)
                          .retryStartup(),
                      child: Text(l10n.splashRetry),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
