import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AuthPageShell extends StatelessWidget {
  final Widget child;

  const AuthPageShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: Stack(
        children: [
          const _Backdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Phones get a little less outer padding so the card is wider.
                final phone = constraints.maxWidth < 600;
                final h = phone ? 16.0 : 20.0;
                final v = phone ? 16.0 : 24.0;

                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.symmetric(horizontal: h, vertical: v),
                  child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight > v * 2
                              ? constraints.maxHeight - v * 2
                              : 0,
                        ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: child,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -70,
            child: _glow(const Color(0xFF2563EB), 260),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: _glow(const Color(0xFF7C3AED), 250),
          ),
          Positioned(
            top: 115,
            left: -110,
            child: _glow(const Color(0xFF0EA5E9), 210),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.22),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 70),
        ],
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  final Widget child;

  const AuthCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 380;

    return Container(
      padding: narrow
          ? const EdgeInsets.fromLTRB(18, 24, 18, 20)
          : const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(narrow ? 24 : 28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.64)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x52030B22),
            blurRadius: 36,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 380;
    final logo = narrow ? 52.0 : 58.0;

    return Column(
      children: [
        Container(
          width: logo,
          height: logo,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF60A5FA), AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'ResumeIQ',
          style: TextStyle(
            color: AppTheme.ink,
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Intelligent hiring, made simple.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }
}
