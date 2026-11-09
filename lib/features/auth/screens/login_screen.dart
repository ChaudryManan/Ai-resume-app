import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_page_shell.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _rememberMe = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

 
Future<void> _login() async {
  if (_loading) return;

  if (!_formKey.currentState!.validate()) {
    return;
  }

  FocusScope.of(context).unfocus();
  setState(() => _loading = true);

  try {
    await AuthService().login(
      _emailController.text,
      _passwordController.text,
    );

    // Get Firebase authentication token
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final token = await user.getIdToken();

      debugPrint("FIREBASE TOKEN: $token");
    }

    // AuthWrapper will automatically open the correct dashboard.

  } on FirebaseAuthException catch (e) {
    debugPrint('Firebase error code: ${e.code}');
    debugPrint('Firebase error message: ${e.message}');

    String message = 'Login failed. Please try again.';

    if (e.code == 'user-not-found') {
      message = 'No account found with this email.';
    } else if (e.code == 'wrong-password' ||
        e.code == 'invalid-credential') {
      message = 'Incorrect email or password.';
    } else if (e.code == 'invalid-email') {
      message = 'Please enter a valid email.';
    } else if (e.code == 'user-disabled') {
      message = 'This account has been disabled.';
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
  } finally {
    // On success AuthWrapper replaces this screen, so check mounted.
    if (mounted) setState(() => _loading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 380;
    final tight = authIsTight(context);

    return AuthPageShell(
      child: AuthCard(
        child: AutofillGroup(
         child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrand(),
              SizedBox(height: tight ? 18 : (narrow ? 26 : 34)),
              Text(
                'Welcome back',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: narrow ? 24 : 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              SizedBox(height: tight ? 16 : (narrow ? 22 : 28)),
              AuthTextField(
                controller: _emailController,
                label: 'Work email',
                hint: 'name@company.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(value.trim())) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              SizedBox(height: tight ? 12 : 19),
              AuthTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Enter your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _hidePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                autocorrect: false,
                onFieldSubmitted: (_) => _login(),
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
                    return 'Please enter your password';
                  if (value.length < 6) return 'At least 6 characters required';
                  return null;
                },
              ),
              SizedBox(height: tight ? 2 : 8),
              // Remember-me + forgot password on one line. The checkbox side
              // shrinks (and ellipsizes) instead of overflowing.
              Row(
                children: [
                  Flexible(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: AppTheme.primary,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (value) => setState(
                                  () => _rememberMe = value ?? false,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'Keep me signed in',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      // Carry over whatever email was already typed.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordScreen(
                            initialEmail: _emailController.text.trim(),
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tight ? 10 : 19),
              AuthPrimaryButton(
                label: 'Sign in to dashboard',
                icon: Icons.arrow_forward_rounded,
                isLoading: _loading,
                onPressed: _login,
              ),
              SizedBox(height: tight ? 16 : 27),
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'NEW TO RESUMEIQ?',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                ],
              ),
              SizedBox(height: tight ? 12 : 18),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, tight ? 48 : 54),
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Create an account',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (!tight) ...[
                const SizedBox(height: 22),
                const Text(
                  'Secure candidate insights, all in one place.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
         ),
        ),
      ),
    );
  }
}
