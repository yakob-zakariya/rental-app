import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/router.dart';
import '../../../core/api/api_error.dart';
import '../../../core/config/app_config_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/auth_repository.dart';
import 'otp_screen.dart';
import 'phone_entry_error.dart';

/// Phone entry (`/sign-in`, spec 3.2): one field, "Send code", then the code
/// screen.
///
/// A `StatefulWidget` (here its Riverpod flavour, `ConsumerStatefulWidget`)
/// keeps local state between rebuilds — like `useState` in React. The state
/// lives in the `State` class below; `setState` tells Flutter to redraw.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  /// Holds the field's text; must be disposed with the screen.
  final _phone = TextEditingController();

  bool _loading = false;

  /// Shown under the field (empty field, INVALID_PHONE).
  String? _fieldError;

  /// Shown above the button (rate limits, SMS failure, connection, ...).
  String? _formError;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final l10n = AppLocalizations.of(context);

    // The only check the app does; the API validates the number itself.
    final phone = _phone.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _fieldError = l10n.phoneEntryEmpty;
        _formError = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _fieldError = null;
      _formError = null;
    });

    final int expiresInSeconds;
    try {
      expiresInSeconds = await ref
          .read(authRepositoryProvider)
          .requestOtp(phone);
    } on ApiError catch (error) {
      // The screen may have closed while we waited.
      if (!mounted) return;
      final message = phoneEntryErrorMessage(error, l10n);
      setState(() {
        _loading = false;
        if (error.code == ApiErrorCode.invalidPhone) {
          _fieldError = message;
        } else {
          _formError = message;
        }
      });
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    // push (not go): Android's back button returns here, number kept.
    await context.push(
      AppRoutes.otp,
      extra: OtpScreenArgs(phone: phone, expiresInSeconds: expiresInSeconds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.signInTitle)),
      body: SafeArea(
        // Scrolls, so the keyboard never covers the field or the button.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.phoneEntryHeadline,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.phoneEntryBody,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _phone,
                    enabled: !_loading,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: l10n.phoneEntryFieldLabel,
                      hintText: l10n.phoneEntryFieldHint,
                      errorText: _fieldError,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_formError case final message?) ...[
                    _FormError(message: message),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? _ButtonSpinner(label: l10n.phoneEntrySending)
                        : Text(l10n.phoneEntrySendCode),
                  ),
                  // Debug builds only: which backend this build talks to.
                  if (kDebugMode) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      ref.watch(appConfigProvider).apiBaseUrl.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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

/// An error message above the button, announced by screen readers.
class _FormError extends StatelessWidget {
  const _FormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// The small spinner shown inside a button while it waits for the API.
class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5, semanticsLabel: label),
    );
  }
}
