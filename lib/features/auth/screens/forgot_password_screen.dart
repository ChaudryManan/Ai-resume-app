import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/auth_page_shell.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  /// The email already typed on the login screen, so it is not typed twice.
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Firebase limits how many reset emails one address can get, so the resend
  // button waits a minute.
  static const int _cooldownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail);

  bool _sending = false;
  bool _sent = false;
  String _sentTo = '';
  String? _error;

  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
      case 'missing-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      default:
        return 'Could not send the email. Please try again.';
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldownSeconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    if (_sending) return;

    FocusScope.of(context).unfocus();

    // When resending, the form is not on screen: use the address we sent to.
    final email = _sent ? _sentTo : _emailController.text.trim();

    if (!_sent && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await AuthService().resetPassword(email);
    } on FirebaseAuthException catch (e) {
      debugPrint('[ForgotPassword] ${e.code}: ${e.message}');

      // Never reveal whether an account exists for an email: an unknown
      // address gets the same "check your email" screen as a known one.
      if (e.code != 'user-not-found') {
        if (!mounted) return;
        setState(() {
          _sending = false;
          _error = _messageFor(e.code);
        });
        return;
      }
    } catch (e) {
      debugPrint('[ForgotPassword] $e');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Could not send the email. Check your connection and try again.';
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _sending = false;
      _sent = true;
      _sentTo = email;
    });
    _startCooldown();
  }

  void _useDifferentEmail() {
    _timer?.cancel();
    setState(() {
      _sent = false;
      _error = null;
      _secondsLeft = 0;
    });
  }

  // ------------------------------------------------------------------ pieces

  Widget _iconBadge(IconData icon, Color color) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 34),
      ),
    );
  }

  Widget _backButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text('Back to sign in'),
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formView() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _backButton(),
          const SizedBox(height: 10),
          _iconBadge(Icons.lock_reset_rounded, AppTheme.primary),
          const SizedBox(height: 20),
          const Text(
            'Forgot your password?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No problem. Enter the email you use to sign in and we will send '
            'you a link to choose a new password.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 26),
          AuthTextField(
            controller: _emailController,
            label: 'Work email',
            hint: 'name@company.com',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _send(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                  .hasMatch(value.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _errorBox(_error!),
          ],
          const SizedBox(height: 22),
          AuthPrimaryButton(
            label: 'Send reset link',
            icon: Icons.send_rounded,
            isLoading: _sending,
            onPressed: _send,
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Remembered it? Sign in',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sentView() {
    return Column(
      key: const ValueKey('sent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        _iconBadge(Icons.mark_email_read_outlined, const Color(0xFF059669)),
        const SizedBox(height: 22),
        const Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.ink,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 14,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'If an account exists for '),
              TextSpan(
                text: _sentTo,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(
                text: ', we have sent a link to reset your password.',
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: AppTheme.textMuted),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cannot see it? Check your spam or junk folder. The link '
                  'only works for a short time.',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _errorBox(_error!),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Back to sign in',
          icon: Icons.login_rounded,
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: (_secondsLeft > 0 || _sending) ? null : _send,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            foregroundColor: AppTheme.primary,
            side: const BorderSide(color: Color(0xFFBFDBFE)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _secondsLeft > 0
                      ? 'Resend email in ${_secondsLeft}s'
                      : 'Resend email',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _useDifferentEmail,
          child: const Text('Use a different email'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      child: AuthCard(
        // Only one view exists at a time (the form owns a GlobalKey), and the
        // card smoothly grows or shrinks between them.
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          curve: Curves.easeOut,
          child: _sent ? _sentView() : _formView(),
        ),
      ),
    );
  }
}
