import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_page_shell.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';

/// Password reset: the user enters their email, Firebase sends a reset link,
/// they choose a new password from that link and then sign in again.
class ForgotPasswordScreen extends StatefulWidget {
  /// Pre-filled from the login screen when the user already typed an email.
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const int _cooldownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  bool _loading = false;
  bool _sent = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- logic

  Future<void> _send({bool fromForm = true}) async {
    if (_loading) return;

    // The resend button lives on the "check your email" view, where the
    // form is not shown, so only validate when sending from the form.
    if (fromForm && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await AuthService().resetPassword(_emailController.text);

      if (!mounted) return;

      setState(() => _sent = true);
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset error code: ${e.code}');

      if (!mounted) return;

      _showMessage(_messageFor(e));
    } catch (_) {
      if (!mounted) return;

      _showMessage('Could not send the reset email. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'too-many-requests':
        return 'Too many requests. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      default:
        return 'Could not send the reset email. Please try again.';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Stops the user from sending the same request again and again.
  void _startCooldown() {
    _timer?.cancel();

    setState(() => _cooldown = _cooldownSeconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _cooldown--;
        if (_cooldown <= 0) timer.cancel();
      });
    });
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final tight = authIsTight(context);

    return AuthPageShell(
      child: AuthCard(
        child: _sent ? _successView(tight) : _formView(tight),
      ),
    );
  }

  Widget _iconTile(IconData icon, bool tight, Color color) {
    final size = tight ? 46.0 : 58.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: color, size: tight ? 24 : 29),
    );
  }

  Widget _signInLink() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Remembered it?',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
          child: const Text(
            'Sign in',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // Step 1: ask for the email.
  Widget _formView(bool tight) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    tooltip: 'Back to sign in',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Reset password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 44),
              ],
            ),
            SizedBox(height: tight ? 16 : 26),
            Center(
              child: _iconTile(Icons.lock_reset_rounded, tight, AppTheme.primary),
            ),
            SizedBox(height: tight ? 12 : 18),
            const Text(
              'Forgot your password?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the email you signed up with and we will send you a '
              'link to choose a new password.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            SizedBox(height: tight ? 18 : 26),
            AuthTextField(
              controller: _emailController,
              label: 'Work email',
              hint: 'name@company.com',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
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
            SizedBox(height: tight ? 16 : 22),
            AuthPrimaryButton(
              label: 'Send reset link',
              icon: Icons.send_rounded,
              isLoading: _loading,
              onPressed: () => _send(),
            ),
            SizedBox(height: tight ? 6 : 14),
            _signInLink(),
          ],
        ),
      ),
    );
  }

  // Step 2: tell the user what to do next.
  Widget _successView(bool tight) {
    final email = _emailController.text.trim();
    final canResend = _cooldown <= 0 && !_loading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _iconTile(
            Icons.mark_email_read_outlined,
            tight,
            const Color(0xFF059669),
          ),
        ),
        SizedBox(height: tight ? 14 : 20),
        const Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13.5,
              height: 1.45,
            ),
            children: [
              const TextSpan(text: 'If an account exists for '),
              TextSpan(
                text: email,
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
        SizedBox(height: tight ? 14 : 20),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _step(1, 'Open the email and tap the reset link.'),
              _step(2, 'Choose your new password.'),
              _step(3, 'Come back here and sign in with it.'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Cannot find it? Check your spam or junk folder.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
        ),
        SizedBox(height: tight ? 14 : 20),
        AuthPrimaryButton(
          label: 'Back to sign in',
          icon: Icons.arrow_forward_rounded,
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: canResend ? () => _send(fromForm: false) : null,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, tight ? 46 : 50),
            foregroundColor: AppTheme.primary,
            side: const BorderSide(color: Color(0xFFBFDBFE)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : Text(
                  _cooldown > 0
                      ? 'Resend email in ${_cooldown}s'
                      : 'Resend email',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
        TextButton(
          onPressed: () => setState(() => _sent = false),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textMuted,
            minimumSize: const Size(0, 40),
          ),
          child: const Text('Use a different email'),
        ),
      ],
    );
  }

  Widget _step(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF334155),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
