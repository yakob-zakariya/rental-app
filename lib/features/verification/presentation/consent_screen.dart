import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/router.dart';
import '../../../app/snack_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/verification_repository.dart';
import 'verification_flow.dart';
import 'verification_messages.dart';

/// Shown before every NEW verification session (spec 3.5 step 1): what is
/// checked and what we keep. "Continue" starts the session and opens Didit.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _starting = false;
  String? _error;

  Future<void> _continue() async {
    if (_starting) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _starting = true;
      _error = null;
    });

    final result = await ref.read(verificationFlowProvider).run();
    if (!mounted) return;
    // Whatever happened, the status may have changed: Home re-reads it.
    ref.invalidate(verificationStatusProvider);

    switch (result) {
      case OpenChecking():
        // Replace this screen: "back" from Checking goes home.
        context.pushReplacement(AppRoutes.verificationChecking);
      case BackHome():
        context.pop();
      case SdkFailed():
        showAppSnackBar(context, l10n.verifyFailedMessage);
        context.pop();
      case StartFailed(:final error):
        final message = startErrorMessage(error, l10n);
        if (message == null) {
          // Approved / in review / blocked: the status card on Home says so.
          context.pop();
        } else {
          setState(() {
            _starting = false;
            _error = message;
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.consentTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.consentHeadline,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.consentBody, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.xl),
                  if (_error case final error?) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  FilledButton(
                    onPressed: _starting ? null : _continue,
                    child: _starting
                        ? SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              semanticsLabel: l10n.consentStarting,
                            ),
                          )
                        : Text(l10n.consentContinue),
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
