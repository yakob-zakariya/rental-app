import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api/api_error.dart';
import '../../../core/device/device_name.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';
import 'otp_error.dart';
import 'phone_entry_error.dart';

/// What the phone entry screen hands to the code screen.
class OtpScreenArgs {
  const OtpScreenArgs({required this.phone, required this.expiresInSeconds});

  /// The number as the user typed it (sent again with the code).
  final String phone;

  /// How long the code stays valid (for the countdown).
  final int expiresInSeconds;
}

/// The 6-digit code length the API uses.
const otpLength = 6;

/// The SMS code screen (`/sign-in/code`, spec 3.3): enter the code, verify,
/// store the tokens, go home. A countdown shows how long the code is valid;
/// "Send a new code" appears when it runs out (or the code can't work any
/// more).
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.args});

  final OtpScreenArgs args;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();

  /// When the current code expires. Time is read through `clock` (not
  /// `DateTime.now()`), so tests can move it forward instantly.
  late DateTime _expiresAt;

  /// Redraws the countdown once a second. Cancelled in [dispose].
  Timer? _ticker;

  bool _verifying = false;
  bool _resending = false;

  /// After OTP_EXPIRED / OTP_ATTEMPTS_EXCEEDED: offer a new code at once.
  bool _needsNewCode = false;

  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.args.expiresInSeconds);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  Duration get _remaining {
    final left = _expiresAt.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get _expired => _remaining == Duration.zero;

  void _startCountdown(int seconds) {
    _expiresAt = clock.now().add(Duration(seconds: seconds));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {}); // redraw the countdown
      if (_expired) timer.cancel();
    });
  }

  void _onCodeChanged(String code) {
    setState(() {}); // enable/disable "Verify"
    if (code.length == otpLength) _verify(); // auto-submit
  }

  Future<void> _verify() async {
    final code = _code.text;
    if (_verifying || code.length != otpLength) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _verifying = true;
      _message = null;
    });

    try {
      final deviceName = await ref.read(deviceNameProvider.future);
      final tokens = await ref
          .read(authRepositoryProvider)
          .verifyOtp(
            phone: widget.args.phone,
            code: code,
            deviceName: deviceName,
          );
      await ref.read(tokenStorageProvider).write(tokens);
    } on ApiError catch (error) {
      if (!mounted) return;
      if (error.code == ApiErrorCode.accountUnavailable) {
        // The router shows the account-unavailable screen.
        ref.read(authControllerProvider.notifier).showAccountUnavailable();
        return;
      }
      setState(() {
        _verifying = false;
        _showError(otpErrorMessage(error, l10n));
        _code.clear();
        _needsNewCode = otpErrorNeedsNewCode(error);
      });
      return;
    } on Exception {
      // e.g. secure storage failed: nothing was stored.
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _showError(l10n.errorGeneric);
      });
      return;
    }

    if (!mounted) return;
    // The router now shows home and removes the sign-in screens, so "back"
    // from home can't return here.
    ref.read(authControllerProvider.notifier).signedIn();
  }

  Future<void> _sendNewCode() async {
    if (_resending) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _resending = true;
      _message = null;
    });

    try {
      final seconds = await ref
          .read(authRepositoryProvider)
          .requestOtp(widget.args.phone);
      if (!mounted) return;
      setState(() {
        _resending = false;
        _needsNewCode = false;
        _code.clear();
        _startCountdown(seconds);
        _message = l10n.otpNewCodeSent;
        _messageIsError = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _showError(phoneEntryErrorMessage(error, l10n));
      });
    }
  }

  void _showError(String message) {
    _message = message;
    _messageIsError = true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canEnterCode = !_expired && !_needsNewCode && !_verifying;
    final showNewCodeButton = _expired || _needsNewCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.otpTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.otpSentTo(widget.args.phone),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _CodeField(
                    controller: _code,
                    enabled: canEnterCode,
                    onChanged: _onCodeChanged,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Countdown(remaining: _remaining),
                  const SizedBox(height: AppSpacing.lg),
                  if (_message case final message?) ...[
                    _Message(text: message, isError: _messageIsError),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  FilledButton(
                    onPressed: canEnterCode && _code.text.length == otpLength
                        ? _verify
                        : null,
                    child: _verifying
                        ? _ButtonSpinner(label: l10n.otpVerifying)
                        : Text(l10n.otpVerify),
                  ),
                  if (showNewCodeButton) ...[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: _resending ? null : _sendNewCode,
                      child: _resending
                          ? _ButtonSpinner(label: l10n.otpSendingNewCode)
                          : Text(l10n.otpSendNewCode),
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

/// One large field for the 6 digits (easier to paste and to use with a
/// screen reader than 6 separate boxes).
class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: true,
      keyboardType: TextInputType.number,
      // Lets Android offer the code from the SMS where the keyboard supports it.
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(otpLength),
      ],
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineMedium
          ?.copyWith(letterSpacing: 12),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: l10n.otpFieldLabel),
    );
  }
}

/// "Code expires in 4:59", or "This code has expired."
class _Countdown extends StatelessWidget {
  const _Countdown({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (remaining == Duration.zero) {
      return Text(
        l10n.otpCodeExpired,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      );
    }
    // Round up, so the last second shows 0:01 (never 0:00 while still valid).
    final total = (remaining.inMilliseconds / 1000).ceil();
    final time = '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
    return Text(
      l10n.otpExpiresIn(time),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// An error or info message, announced by screen readers.
class _Message extends StatelessWidget {
  const _Message({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isError ? scheme.error : scheme.onSurface;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

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
