import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../app/snack_bar.dart';
import '../../../core/api/api_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../verification/data/verification_status.dart';
import '../data/profile_repository.dart';
import '../data/user_profile.dart';
import 'profile_format.dart';

/// Profile and settings (`/settings`, spec 3.7): phone, verification status,
/// the verified name and date of birth (read-only), language, sign-out.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// The language being saved (its row shows a spinner).
  String? _savingLanguage;

  Future<void> _changeLanguage(String? code) async {
    final current = ref.read(meProvider).value?.preferredLanguage;
    if (code == null || code == current || _savingLanguage != null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _savingLanguage = code);

    try {
      await ref.read(profileRepositoryProvider).updateLanguage(code);
      // Reload, and keep the spinner until the new choice is shown.
      ref.invalidate(meProvider);
      await ref.read(meProvider.future);
    } on ApiError catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          error.isNetworkError ? l10n.errorNetwork : l10n.errorGeneric,
        );
      }
    } finally {
      if (mounted) setState(() => _savingLanguage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(meProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          switch (me) {
            AsyncValue(:final value?) => _Profile(
              me: value,
              savingLanguage: _savingLanguage,
              onLanguageChanged: _changeLanguage,
            ),
            AsyncValue(:final error?, isLoading: false) => _LoadError(
              error: error,
              onRetry: () => ref.invalidate(meProvider),
            ),
            _ => Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.settingsLoading,
                ),
              ),
            ),
          },
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: Text(l10n.homeSignOut),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
            ),
            child: Text(l10n.settingsLicences),
          ),
        ],
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({
    required this.me,
    required this.savingLanguage,
    required this.onLanguageChanged,
  });

  final UserProfile me;
  final String? savingLanguage;
  final ValueChanged<String?> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final approved = me.verificationStatus == VerificationStatus.approved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: l10n.settingsAccount,
          children: [
            _Field(
              label: l10n.settingsPhone,
              value: formatPhoneForDisplay(me.phone),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: l10n.settingsVerification,
          children: [
            Text(
              verificationStatusLabel(me.verificationStatus, l10n),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            // Read-only identity data, only once approved.
            if (approved && me.fullName != null)
              _Field(label: l10n.settingsVerifiedName, value: me.fullName!),
            if (approved && me.dateOfBirth != null)
              // Exactly as received: YYYY-MM-DD, Gregorian (confirmed in A13).
              _Field(label: l10n.settingsDateOfBirth, value: me.dateOfBirth!),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _LanguageSection(
          selected: me.preferredLanguage,
          saving: savingLanguage,
          onChanged: onLanguageChanged,
        ),
      ],
    );
  }
}

class _LanguageSection extends StatelessWidget {
  const _LanguageSection({
    required this.selected,
    required this.saving,
    required this.onChanged,
  });

  final String selected;
  final String? saving;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return _Section(
      title: l10n.settingsLanguage,
      children: [
        // RadioGroup holds the choice; its RadioListTiles are the options.
        RadioGroup<String>(
          groupValue: selected,
          onChanged: onChanged,
          child: Column(
            children: [
              for (final (code, label) in languageChoices(l10n))
                RadioListTile<String>(
                  value: code,
                  title: Text(label),
                  enabled: saving == null,
                  contentPadding: EdgeInsets.zero,
                  secondary: saving == code
                      ? SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            semanticsLabel: l10n.settingsSaving,
                          ),
                        )
                      : null,
                ),
            ],
          ),
        ),
        Text(
          l10n.settingsLanguageNote,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A card with a heading.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            for (final child in children) ...[
              const SizedBox(height: AppSpacing.sm),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// A read-only label + value.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final offline = error is ApiError && (error as ApiError).isNetworkError;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              offline ? l10n.errorNetwork : l10n.errorGeneric,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
