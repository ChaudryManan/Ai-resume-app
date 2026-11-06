import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../widgets/auth_page_shell.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  
Future<void> _signup() async {
  // Check form validation
  if (!_formKey.currentState!.validate()) {
    return;
  }

  try {
    // Call Firebase signup service
    await AuthService().signup(
      _nameController.text,
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;

    Navigator.of(context).pop();
    // AuthWrapper will automatically open the User Dashboard.

  } on FirebaseAuthException catch (e) {
    debugPrint('Firebase error code: ${e.code}');
    debugPrint('Firebase error message: ${e.message}');
    String message = 'Signup failed. Please try again.';

    if (e.code == 'email-already-in-use') {
      message = 'This email is already registered.';
    } else if (e.code == 'weak-password') {
      message = 'Please choose a stronger password.';
    } else if (e.code == 'invalid-email') {
      message = 'Please enter a valid email address.';
    } else if (e.code == 'network-request-failed') {
      message = 'Please check your internet connection.';
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An error occurred: $e')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      child: AuthCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
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
                      'Create your workspace',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: AppTheme.primary,
                    size: 29,
                  ),
                ),
              ),
              const SizedBox(height: 17),
              const Text(
                'Start hiring smarter',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Create your account and turn resumes into confident decisions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 27),
              AuthTextField(
                controller: _nameController,
                label: 'Full name',
                hint: 'Enter your full name',
                prefixIcon: Icons.person_outline_rounded,
                keyboardType: TextInputType.name,
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Please enter your full name';
                  return null;
                },
              ),
              const SizedBox(height: 17),
              AuthTextField(
                controller: _emailController,
                label: 'Work email',
                hint: 'name@company.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Please enter your email';
                  if (!RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(value.trim()))
                    return 'Enter a valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 17),
              AuthTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Create a strong password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _hidePassword,
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppTheme.textMuted,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please create a password';
                  if (value.length < 6) return 'Use at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 17),
              AuthTextField(
                controller: _confirmPasswordController,
                label: 'Confirm password',
                hint: 'Enter your password again',
                prefixIcon: Icons.lock_reset_rounded,
                obscureText: _hideConfirmPassword,
                suffixIcon: IconButton(
                  tooltip: _hideConfirmPassword
                      ? 'Show password'
                      : 'Hide password',
                  onPressed: () => setState(
                    () => _hideConfirmPassword = !_hideConfirmPassword,
                  ),
                  icon: Icon(
                    _hideConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppTheme.textMuted,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please confirm your password';
                  if (value != _passwordController.text)
                    return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              AuthPrimaryButton(
                label: 'Create account',
                icon: Icons.arrow_forward_rounded,
                onPressed: _signup,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                    ),
                    child: const Text(
                      'Sign in',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
