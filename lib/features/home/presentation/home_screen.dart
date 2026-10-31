import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Home (`/home`). A9 adds the verification status cards (from
/// `features/verification/`); later phases turn it into the listings feed.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: [
          // Settings joins this menu in A11.
          PopupMenuButton<_HomeMenu>(
            tooltip: l10n.homeMenuTooltip,
            onSelected: (item) => switch (item) {
              _HomeMenu.signOut =>
                ref.read(authControllerProvider.notifier).signOut(),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _HomeMenu.signOut,
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(l10n.homeSignOut),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        // Placeholder until A9's verification cards.
        child: Text(
          l10n.homeSignedInPlaceholder,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

enum _HomeMenu { signOut }
