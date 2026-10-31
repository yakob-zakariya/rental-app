import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'auth_controller.dart';

/// Shown on ACCOUNT_UNAVAILABLE anywhere (spec 3.8). Neutral text only —
/// never a reason (hard rule 8). The tokens are already cleared.
class AccountUnavailableScreen extends ConsumerWidget {
  const AccountUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

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
                  Icon(
                    Icons.support_agent_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.accountUnavailableMessage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () => ref
                        .read(authControllerProvider.notifier)
                        .backToSignIn(),
                    child: Text(l10n.accountUnavailableBackToSignIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
