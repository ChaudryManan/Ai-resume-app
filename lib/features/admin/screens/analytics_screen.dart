import 'package:flutter/material.dart';

/// Analytics page.
///
/// Layout rules (same breakpoints as Overview):
///  * width < 600  -> phone: 16px padding, 2-column compact stat cards,
///                    charts stacked, slightly larger chart text.
///  * width >= 600 -> tablet / desktop: 25px padding, content capped at 1100.
///  * width >= 760 -> 4 stat cards in one row.
///  * width >= 850 -> charts sit side by side.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  static const Color navy = Color(0xFF172554);
  static const Color blue = Color(0xFF4F6EF7);
  static const Color background = Color(0xFFF5F7FC);
  static const Color _muted = Color(0xFF64748B);
  static const Color _faint = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE9EDF5);

  final List<Map<String, dynamic>> monthlyApplications = const [
    {'month': 'May', 'count': 35},
    {'month': 'Jun', 'count': 52},
    {'month': 'Jul', 'count': 44},
    {'month': 'Aug', 'count': 68},
    {'month': 'Sep', 'count': 58},
    {'month': 'Oct', 'count': 85},
  ];

  final List<Map<String, dynamic>> applicationStatuses = const [
    {'label': 'Pending', 'count': 120, 'color': Color(0xFFD97706)},
    {'label': 'Shortlisted', 'count': 85, 'color': Color(0xFF059669)},
    {'label': 'Rejected', 'count': 43, 'color': Color(0xFFDC6262)},
  ];

  final List<Map<String, dynamic>> scoreDistribution = const [
    {'range': '90-100%', 'count': 32},
    {'range': '80-89%', 'count': 48},
    {'range': '70-79%', 'count': 65},
    {'range': '60-69%', 'count': 38},
    {'range': 'Below 60%', 'count': 20},
  ];

  final List<Map<String, dynamic>> popularJobs = const [
    {'title': 'AI Engineer', 'applications': 85},
    {'title': 'Flutter Developer', 'applications': 68},
    {'title': 'Python Developer', 'applications': 52},
    {'title': 'Frontend Developer', 'applications': 41},
  ];

  // ------------------------------------------------------------ stat card

  Widget statCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color, {
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A172554),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: compact ? 12 : 16),
          Text(
            value,
            style: TextStyle(
              color: navy,
              fontSize: compact ? 26 : 30,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: navy,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statGrid(double contentWidth, bool compact) {
    final columns = contentWidth >= 760 ? 4 : 2;
    const gap = 12.0;
    final width = (contentWidth - gap * (columns - 1)) / columns;

    Widget cell(
      String title,
      String value,
      String subtitle,
      IconData icon,
      Color color,
    ) {
      return SizedBox(
        width: width,
        child: statCard(title, value, subtitle, icon, color, compact: compact),
      );
    }

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        cell(
          'Total Applications',
          '248',
          'Across all positions',
          Icons.description_outlined,
          blue,
        ),
        cell(
          'Shortlisted',
          '85',
          'Candidates selected',
          Icons.check_circle_outline,
          const Color(0xFF059669),
        ),
        cell(
          'Active Jobs',
          '12',
          'Currently accepting',
          Icons.work_outline,
          const Color(0xFF0D9488),
        ),
        cell(
          'Avg. ATS Score',
          '78%',
          'Across applicants',
          Icons.analytics_outlined,
          const Color(0xFFD97706),
        ),
      ],
    );
  }

  // --------------------------------------------------------- section card

  Widget sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    required bool compact,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A172554),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: navy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: _faint, fontSize: 12, height: 1.35),
          ),
          SizedBox(height: compact ? 18 : 24),
          child,
        ],
      ),
    );
  }

  // --------------------------------------------------------------- charts

  Widget monthlyChart({required bool compact}) {
    final maxCount = monthlyApplications
        .map((item) => item['count'] as int)
        .reduce((a, b) => a > b ? a : b);

    final maxBar = compact ? 118.0 : 155.0;

    return SizedBox(
      height: compact ? 190 : 230,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: monthlyApplications.map((item) {
          final count = item['count'] as int;
          final barHeight = (count / maxCount) * maxBar;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: barHeight,
                    decoration: const BoxDecoration(
                      color: blue,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['month'],
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget statusChart({required bool compact}) {
    final total = applicationStatuses.fold<int>(
      0,
      (sum, item) => sum + (item['count'] as int),
    );

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: applicationStatuses.map((item) {
              final percentage = (item['count'] / total) as double;

              return Expanded(
                flex: (percentage * 1000).round(),
                child: Container(
                  height: compact ? 14 : 17,
                  margin: const EdgeInsets.only(right: 2),
                  color: item['color'],
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: compact ? 18 : 24),
        ...applicationStatuses.map((item) {
          final percentage = (item['count'] / total * 100).toStringAsFixed(1);

          return Padding(
            padding: EdgeInsets.only(bottom: compact ? 14 : 17),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item['color'],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item['label'],
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ),
                Text(
                  '${item['count']}',
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 52,
                  child: Text(
                    '$percentage%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget scoreChart({required bool compact}) {
    final maxScore = scoreDistribution
        .map((item) => item['count'] as int)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: scoreDistribution.map((item) {
        final count = item['count'] as int;

        return Padding(
          padding: EdgeInsets.only(bottom: compact ? 14 : 17),
          child: Row(
            children: [
              SizedBox(
                width: compact ? 78 : 80,
                child: Text(
                  item['range'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: count / maxScore,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFEEF2F7),
                    color: blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 28,
                child: Text(
                  '$count',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget popularJobsChart({required bool compact}) {
    final maxApplications = popularJobs
        .map((item) => item['applications'] as int)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: popularJobs.map((job) {
        final count = job['applications'] as int;

        return Padding(
          padding: EdgeInsets.only(bottom: compact ? 16 : 19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job['title'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count applications',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: count / maxApplications,
                  minHeight: 9,
                  backgroundColor: const Color(0xFFEEF2F7),
                  color: const Color(0xFF0D9488),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --------------------------------------------------------------- header

  Widget _header(bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recruitment Analytics',
          style: TextStyle(
            color: navy,
            fontSize: compact ? 24 : 27,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Track your hiring performance and candidate activity.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  Widget _banner(bool compact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.insights_outlined,
              color: Color(0xFF9DB1FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recruitment Performance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Use ATS scores and application trends to identify '
                  'strong candidates and improve your hiring process.',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Two cards side by side on wide screens, stacked on narrow ones.
  Widget _pair({
    required bool wide,
    required Widget first,
    required Widget second,
    int firstFlex = 1,
    int secondFlex = 1,
  }) {
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: firstFlex, child: first),
          const SizedBox(width: 16),
          Expanded(flex: secondFlex, child: second),
        ],
      );
    }

    return Column(
      children: [
        first,
        const SizedBox(height: 14),
        second,
      ],
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final padding = compact ? 16.0 : 25.0;
          final contentWidth = (constraints.maxWidth - padding * 2)
              .clamp(0.0, 1100.0)
              .toDouble();
          final wide = contentWidth >= 800;
          final gap = compact ? 14.0 : 18.0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(compact),
                    SizedBox(height: compact ? 18 : 24),
                    _statGrid(contentWidth, compact),
                    SizedBox(height: gap + 4),
                    _pair(
                      wide: wide,
                      firstFlex: 3,
                      secondFlex: 2,
                      first: sectionCard(
                        title: 'Application Overview',
                        subtitle: 'Applications received over the last six months',
                        compact: compact,
                        child: monthlyChart(compact: compact),
                      ),
                      second: sectionCard(
                        title: 'Application Status',
                        subtitle: 'Distribution of candidate applications',
                        compact: compact,
                        child: statusChart(compact: compact),
                      ),
                    ),
                    SizedBox(height: gap),
                    _pair(
                      wide: wide,
                      first: sectionCard(
                        title: 'ATS Score Distribution',
                        subtitle: 'Candidate scores grouped by matching percentage',
                        compact: compact,
                        child: scoreChart(compact: compact),
                      ),
                      second: sectionCard(
                        title: 'Popular Job Positions',
                        subtitle: 'Applications received by job position',
                        compact: compact,
                        child: popularJobsChart(compact: compact),
                      ),
                    ),
                    SizedBox(height: gap),
                    _banner(compact),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
