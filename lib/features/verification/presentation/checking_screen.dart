import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/router.dart';
import '../../../app/snack_bar.dart';
import '../../../core/api/api_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/verification_repository.dart';
import '../data/verification_status.dart';
import 'manual_review.dart';
import 'widgets/verification_status_card.dart';

/// After the Didit flow completed (spec 3.5 step 4): polls
/// `GET /verification/status` until the backend has decided — the SDK's own
/// result is never the answer (hard rule 5).
class CheckingScreen extends ConsumerStatefulWidget {
  const CheckingScreen({super.key});

  /// Poll this often during the first minute…
  static const fastInterval = Duration(seconds: 5);

  /// …and this often afterwards.
  static const slowInterval = Duration(seconds: 30);
  static const fastPhase = Duration(minutes: 1);

  @override
  ConsumerState<CheckingScreen> createState() => _CheckingScreenState();
}

class _CheckingScreenState extends ConsumerState<CheckingScreen> {
  late final DateTime _openedAt;
  late final AppLifecycleListener _lifecycle;
  Timer? _next;
  bool _polling = false;

  /// The decision, once the status is no longer pending.
  VerificationSummary? _result;

  /// The last poll failed (shown as a hint; polling continues).
  ApiError? _pollError;

  VerificationAction? _busy;

  @override
  void initState() {
    super.initState();
    _openedAt = clock.now();
    _lifecycle = AppLifecycleListener(onResume: _poll);
    _poll();
  }

  @override
  void dispose() {
    _next?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  bool get _pastFirstMinute =>
      clock.now().difference(_openedAt) >= CheckingScreen.fastPhase;

  Future<void> _poll() async {
    if (_polling || _result != null) return;
    _polling = true;
    _next?.cancel();
    try {
      final summary = await ref
          .read(verificationRepositoryProvider)
          .getStatus();
      if (!mounted) return;
      setState(() {
        _pollError = null;
        if (summary.status != VerificationStatus.pending) _result = summary;
      });
      if (_result != null) ref.invalidate(verificationStatusProvider);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _pollError = error);
    } finally {
      _polling = false;
      if (mounted && _result == null) {
        _next = Timer(
          _pastFirstMinute
              ? CheckingScreen.slowInterval
              : CheckingScreen.fastInterval,
          _poll,
        );
      }
    }
  }

  Future<void> _requestManualReview() async {
    final l10n = AppLocalizations.of(context);
    if (!await confirmManualReview(context) || !mounted) return;
    setState(() => _busy = VerificationAction.manualReview);
    final message = await submitManualReview(ref, l10n);
    if (!mounted) return;
    if (message != null) showAppSnackBar(context, message);
    context.pop(); // Home shows the reloaded status.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkingTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (result == null)
              _Waiting(error: _pollError, showLeaveHint: _pastFirstMinute)
            else ...[
              VerificationStatusCard(
                summary: result,
                busy: _busy,
                actions: VerificationActions(
                  // A new session starts with the consent screen again.
                  onVerify: () =>
                      context.pushReplacement(AppRoutes.verificationConsent),
                  onTryAgain: () =>
                      context.pushReplacement(AppRoutes.verificationConsent),
                  onContinue: () => context.pop(),
                  onRequestManualReview: _requestManualReview,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(l10n.checkingBackHome),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Checking your verification…" with a spinner, and hints.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.error, required this.showLeaveHint});

  final ApiError? error;
  final bool showLeaveHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = switch (error) {
      null => null,
      final e when e.isNetworkError => l10n.checkingOfflineHint,
      _ => l10n.checkingErrorHint,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.verifyPendingTitle,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.verifyPendingTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.verifyPendingBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (showLeaveHint) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.checkingLeaveHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (hint != null) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
