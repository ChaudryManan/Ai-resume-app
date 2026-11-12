import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Design tokens for the candidate screens. They match the admin side:
/// navy + blue, white cards with a soft shadow on a pale blue background.
class UserUi {
  UserUi._();

  static const Color navy = Color(0xFF172554);
  static const Color blue = Color(0xFF4F6EF7);
  static const Color background = Color(0xFFF5F7FC);
  static const Color border = Color(0xFFE9EDF5);
  static const Color body = Color(0xFF334155);
  static const Color muted = Color(0xFF64748B);
  static const Color faint = Color(0xFF94A3B8);
  static const Color track = Color(0xFFEEF2F7);

  static const Color green = Color(0xFF059669);
  static const Color amber = Color(0xFFD97706);
  static const Color red = Color(0xFFDC6262);
  static const Color teal = Color(0xFF0D9488);
  static const Color slate = Color(0xFF94A3B8);

  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x0A172554), blurRadius: 14, offset: Offset(0, 4)),
  ];

  static BoxDecoration card({double radius = 16, Color color = Colors.white}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: softShadow,
    );
  }

  // ---- eligibility bands (highly_eligible / potential / low_match) ----

  static Color eligibilityColor(String key) {
    switch (key) {
      case 'highly_eligible':
        return green;
      case 'potential':
        return amber;
      default:
        return slate;
    }
  }

  static String eligibilityLabel(String key) {
    switch (key) {
      case 'highly_eligible':
        return 'Highly eligible';
      case 'potential':
        return 'High potential';
      default:
        return 'Low match';
    }
  }

  static IconData eligibilityIcon(String key) {
    switch (key) {
      case 'highly_eligible':
        return Icons.verified_rounded;
      case 'potential':
        return Icons.trending_up_rounded;
      default:
        return Icons.remove_circle_outline_rounded;
    }
  }

  static String initialOf(String? name) {
    final text = (name ?? '').trim();
    if (text.isEmpty) return '?';
    return String.fromCharCode(text.runes.first).toUpperCase();
  }

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "8 Nov 2026"
  static String dateText(DateTime date) {
    final local = date.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }
}

/// Page frame shared by the three tabs: pale background, padding that shrinks
/// on phones, content capped at 1100px and optional pull-to-refresh.
class UserPage extends StatelessWidget {
  const UserPage({super.key, required this.builder, this.onRefresh});

  final Widget Function(BuildContext context, bool compact, double contentWidth)
  builder;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: UserUi.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final padding = compact ? 16.0 : 25.0;
          final contentWidth = (constraints.maxWidth - padding * 2)
              .clamp(0.0, 1100.0)
              .toDouble();

          Widget scroll = SingleChildScrollView(
            physics: onRefresh != null
                ? const AlwaysScrollableScrollPhysics()
                : null,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              padding,
              compact ? 16 : 24,
              padding,
              24,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: builder(context, compact, contentWidth),
              ),
            ),
          );

          if (onRefresh != null) {
            scroll = RefreshIndicator(
              color: UserUi.blue,
              onRefresh: onRefresh!,
              child: scroll,
            );
          }

          return scroll;
        },
      ),
    );
  }
}

/// White rounded card.
class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: UserUi.card(radius: radius),
      child: child,
    );
  }
}

/// Icon tile + title (+ optional subtitle and trailing widget).
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.color = UserUi.blue,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: UserUi.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: UserUi.faint,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// Small rounded status label.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A skill / keyword chip.
class SkillChip extends StatelessWidget {
  const SkillChip({
    super.key,
    required this.text,
    this.color = UserUi.blue,
    this.icon,
  });

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin rounded progress bar. [value] is 0..1.
class MiniBar extends StatelessWidget {
  const MiniBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0).toDouble(),
        minHeight: height,
        backgroundColor: UserUi.track,
        color: color,
      ),
    );
  }
}

/// Grey placeholder shown while data loads.
class SkeletonBar extends StatelessWidget {
  const SkeletonBar({super.key, this.width, this.height = 12});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: UserUi.track,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Circular score gauge that animates from 0 to [value] (0..100).
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 56,
    this.strokeWidth = 6,
    this.trackColor = UserUi.track,
    this.child,
  });

  final double value;
  final Color color;
  final double size;
  final double strokeWidth;
  final Color trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final target = (value / 100).clamp(0.0, 1.0).toDouble();

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: target),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, progress, inner) {
          return CustomPaint(
            painter: _RingPainter(
              progress: progress,
              color: color,
              trackColor: trackColor,
              strokeWidth: strokeWidth,
            ),
            child: inner,
          );
        },
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (progress > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) {
    return old.progress != progress ||
        old.color != color ||
        old.trackColor != trackColor ||
        old.strokeWidth != strokeWidth;
  }
}
