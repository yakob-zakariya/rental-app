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
import '../../auth/presentation/auth_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../verification/data/verification_repository.dart';
import '../../verification/data/verification_status.dart';
import '../../verification/presentation/manual_review.dart';
import '../../verification/presentation/verification_flow.dart';
import '../../verification/presentation/verification_messages.dart';
import '../../verification/presentation/widgets/verification_status_card.dart';

/// Home (`/home`, spec 3.4): the verification status card. Refreshed when
/// the screen opens, on pull-to-refresh, when the app returns to the
/// foreground, and when `retryAvailableAt` passes. Later phases turn home
/// into the listings feed.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Calls [_reload] when the app comes back to the foreground.
  late final AppLifecycleListener _lifecycle;

  /// Fires once when `retryAvailableAt` passes.
  Timer? _retryTimer;

  /// The card action that is running (its button shows a spinner).
  VerificationAction? _busy;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _reload);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _retryTimer?.cancel();
    super.dispose();
  }

  /// Forget the loaded data; it's fetched again because the screen watches it.
  void _reload() {
    ref.invalidate(verificationStatusProvider);
    ref.invalidate(meProvider);
  }

  /// Pull-to-refresh: the spinner stays until the new status has arrived.
  Future<void> _pullToRefresh() async {
    _reload();
    try {
      await ref.read(verificationStatusProvider.future);
    } on ApiError {
      // Reported by the SnackBar (see [_onStatusChanged]).
    }
  }

  void _onStatusChanged(AsyncValue<VerificationSummary> next) {
    _scheduleRetryReload(next.value);

    // A reload (pull-to-refresh, foreground, retry time) failed, but the last
    // status is still known: keep the card, say so in a SnackBar. (Riverpod
    // keeps the previous value in the new state when a reload fails.)
    if (!next.isLoading && next.hasError && next.hasValue) {
      final l10n = AppLocalizations.of(context);
      final error = next.error;
      final offline = error is ApiError && error.isNetworkError;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              offline ? l10n.homeRefreshFailedOffline : l10n.errorGeneric,
            ),
          ),
        );
    }
  }

  /// "Verify my identity" / "Try again": a NEW session, so consent first.
  void _startNew() => context.push(AppRoutes.verificationConsent);

  /// "Continue verification": resume the open session, no consent screen.
  Future<void> _resume() async {
    if (_busy != null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = VerificationAction.resume);
    final result = await ref.read(verificationFlowProvider).run();
    if (!mounted) return;
    setState(() => _busy = null);
    _reload();

    switch (result) {
      case OpenChecking():
        await context.push(AppRoutes.verificationChecking);
      case BackHome():
        break; // the reloaded card offers "Continue verification" again
      case SdkFailed():
        showAppSnackBar(context, l10n.verifyFailedMessage);
      case StartFailed(:final error):
        if (startErrorMessage(error, l10n) case final message?) {
          showAppSnackBar(context, message);
        }
    }
  }

  /// "Request manual review": confirm, send, reload (spec 3.6).
  Future<void> _requestManualReview() async {
    if (_busy != null) return;
    final l10n = AppLocalizations.of(context);
    if (!await confirmManualReview(context) || !mounted) return;
    setState(() => _busy = VerificationAction.manualReview);
    final message = await submitManualReview(ref, l10n);
    if (!mounted) return;
    setState(() => _busy = null);
    if (message != null) showAppSnackBar(context, message);
  }

  /// Out of tries: re-fetch once the API says a new session can start
  /// (never assume `canRetry` changed — the API decides).
  void _scheduleRetryReload(VerificationSummary? summary) {
    _retryTimer?.cancel();
    final at = summary?.retryAvailableAt;
    if (summary == null || summary.canRetry || at == null) return;
    final wait = at.difference(clock.now());
    _retryTimer = Timer(
      wait.isNegative ? Duration.zero : wait + const Duration(seconds: 1),
      _reload,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(verificationStatusProvider);
    ref.listen(verificationStatusProvider, (_, next) => _onStatusChanged(next));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle), actions: const [_HomeMenu()]),
      body: RefreshIndicator(
        onRefresh: _pullToRefresh,
        // A list, so pull-to-refresh works even when the content is short.
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            switch (status) {
              // The last known status: also kept while a reload runs, and
              // when a reload fails (then a SnackBar says so).
              AsyncValue(:final value?) => _StatusCard(
                summary: value,
                busy: _busy,
                actions: VerificationActions(
                  onVerify: _startNew,
                  onTryAgain: _startNew,
                  onContinue: _resume,
                  onRequestManualReview: _requestManualReview,
                ),
              ),
              // The first load failed: message + Retry.
              AsyncValue(:final error?, isLoading: false) => _LoadError(
                error: error,
                onRetry: _reload,
              ),
              _ => _LoadingCard(label: l10n.homeLoadingStatus),
            },
          ],
        ),
      ),
    );
  }
}

/// The status card; for an approved user it also loads the verified name.
class _StatusCard extends ConsumerWidget {
  const _StatusCard({
    required this.summary,
    required this.actions,
    required this.busy,
  });

  final VerificationSummary summary;
  final VerificationActions actions;
  final VerificationAction? busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = summary.status == VerificationStatus.approved
        ? ref.watch(meProvider).value?.fullName
        : null;
    return VerificationStatusCard(
      summary: summary,
      verifiedName: name,
      actions: actions,
      busy: busy,
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator(semanticsLabel: label)),
      ),
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
    final theme = Theme.of(context);
    final offline = error is ApiError && (error as ApiError).isNetworkError;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              offline ? Icons.cloud_off_outlined : Icons.error_outline,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              offline ? l10n.errorNetwork : l10n.errorGeneric,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}

/// The app-bar menu. Settings joins it in A11.
class _HomeMenu extends ConsumerWidget {
  const _HomeMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_MenuItem>(
      tooltip: l10n.homeMenuTooltip,
      onSelected: (item) => switch (item) {
        _MenuItem.signOut =>
          ref.read(authControllerProvider.notifier).signOut(),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _MenuItem.signOut,
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.homeSignOut),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

enum _MenuItem { signOut }
