import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../data/verification_status.dart';
import '../verification_messages.dart';

/// What the card's buttons do. The card only decides *which* buttons appear,
/// and only from the API's flags (hard rule 7).
class VerificationActions {
  const VerificationActions({
    required this.onVerify,
    required this.onContinue,
    required this.onTryAgain,
    required this.onRequestManualReview,
  });

  /// A9: every button is shown but does nothing yet; A10 connects them.
  static final noop = VerificationActions(
    onVerify: () {},
    onContinue: () {},
    onTryAgain: () {},
    onRequestManualReview: () {},
  );

  final VoidCallback onVerify;
  final VoidCallback onContinue;
  final VoidCallback onTryAgain;
  final VoidCallback onRequestManualReview;
}

/// One card per verification status (spec 3.4).
class VerificationStatusCard extends StatelessWidget {
  const VerificationStatusCard({
    super.key,
    required this.summary,
    required this.actions,
    this.verifiedName,
  });

  final VerificationSummary summary;
  final VerificationActions actions;

  /// From `GET /me`, for the approved card (null until loaded).
  final String? verifiedName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = summary;

    final _CardContent content = switch (s.status) {
      VerificationStatus.notVerified => _CardContent(
        icon: Icons.badge_outlined,
        title: l10n.verifyNotVerifiedTitle,
        body: l10n.verifyNotVerifiedBody,
        buttons: [_Main(l10n.verifyNotVerifiedButton, actions.onVerify)],
      ),
      VerificationStatus.pending => _CardContent(
        icon: Icons.hourglass_top_outlined,
        title: l10n.verifyPendingTitle,
        body: l10n.verifyPendingBody,
        buttons: [
          if (s.canRetry) _Main(l10n.verifyContinueButton, actions.onContinue),
        ],
      ),
      VerificationStatus.approved => _CardContent(
        icon: Icons.verified,
        title: l10n.verifyApprovedTitle,
        body: switch (verifiedName) {
          final name? => l10n.verifyApprovedAs(name),
          null => l10n.verifyApprovedBody,
        },
        highlight: true,
      ),
      VerificationStatus.declined => _CardContent(
        icon: Icons.error_outline,
        title: l10n.verifyDeclinedTitle,
        body: declineReasonMessage(s.reasonCode, l10n),
        note: s.canRetry ? null : retryTimeMessage(s.retryAvailableAt, l10n),
        buttons: [
          if (s.canRetry) _Main(l10n.verifyTryAgainButton, actions.onTryAgain),
          if (s.canRequestManualReview)
            _Secondary(
              l10n.verifyManualReviewButton,
              actions.onRequestManualReview,
            ),
        ],
      ),
      VerificationStatus.manualReview => _CardContent(
        icon: Icons.manage_search_outlined,
        title: l10n.verifyManualReviewTitle,
        body: l10n.verifyManualReviewBody,
      ),
      // Neutral, no reason and no buttons (hard rule 8).
      VerificationStatus.blocked => _CardContent(
        icon: Icons.support_agent_outlined,
        body: l10n.verifyBlockedBody,
      ),
      VerificationStatus.unknown => _CardContent(
        icon: Icons.help_outline,
        body: l10n.verifyUnknownBody,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: content,
      ),
    );
  }
}

/// The layout every status shares: icon + title, body, an optional note,
/// then the buttons.
class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.icon,
    required this.body,
    this.title,
    this.note,
    this.buttons = const [],
    this.highlight = false,
  });

  final IconData icon;
  final String? title;
  final String body;
  final String? note;
  final List<Widget> buttons;

  /// The approved badge uses the accent colour.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconColor = highlight ? scheme.primary : scheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title ?? body,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: highlight ? scheme.primary : null,
                ),
              ),
            ),
          ],
        ),
        if (title != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: theme.textTheme.bodyLarge),
        ],
        if (note case final note?) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            note,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        for (final button in buttons) ...[
          const SizedBox(height: AppSpacing.sm),
          button,
        ],
      ],
    );
  }
}

class _Main extends StatelessWidget {
  const _Main(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      FilledButton(onPressed: onPressed, child: Text(label));
}

class _Secondary extends StatelessWidget {
  const _Secondary(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: onPressed, child: Text(label));
}
