import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/verification_repository.dart';
import 'verification_messages.dart';

/// "Request a manual review?" Returns true when the user confirms.
Future<bool> confirmManualReview(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.manualReviewDialogTitle),
      content: Text(l10n.manualReviewDialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.manualReviewDialogCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.manualReviewDialogConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// `POST /verification/manual-review-request` (spec 3.6), then reloads the
/// status. Returns a message to show, or `null` when the reloaded card says
/// it all.
Future<String?> submitManualReview(WidgetRef ref, AppLocalizations l10n) async {
  try {
    await ref.read(verificationRepositoryProvider).requestManualReview();
    return null;
  } on ApiError catch (error) {
    return manualReviewErrorMessage(error, l10n);
  } finally {
    ref.invalidate(verificationStatusProvider);
  }
}
