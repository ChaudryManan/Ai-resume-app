
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' show WidgetStateProperty;

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  static const Color navy = Color(0xFF172554);
  static const Color blue = Color(0xFF4F6EF7);
  static const Color background = Color(0xFFF5F7FC);

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

  Widget statCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EDF5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE9EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: navy,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget monthlyChart() {
    final maxCount = monthlyApplications
        .map((item) => item['count'] as int)
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 230,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: monthlyApplications.map((item) {
          final count = item['count'] as int;
          final barHeight = (count / maxCount) * 155;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: blue,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item['month'],
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget statusChart() {
    final total = applicationStatuses.fold<int>(
      0,
      (sum, item) => sum + (item['count'] as int),
    );

    return Column(
      children: [
        Row(
          children: applicationStatuses.map((item) {
            final percentage = (item['count'] / total) as double;

            return Expanded(
              flex: (percentage * 1000).round(),
              child: Container(
                height: 17,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: item['color'],
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        ...applicationStatuses.map((item) {
          final percentage =
              (item['count'] / total * 100).toStringAsFixed(1);

          return Padding(
            padding: const EdgeInsets.only(bottom: 17),
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
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '${item['count']}',
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 48,
                  child: Text(
                    '$percentage%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget scoreChart() {
    final maxScore = scoreDistribution
        .map((item) => item['count'] as int)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: scoreDistribution.map((item) {
        final count = item['count'] as int;

        return Padding(
          padding: const EdgeInsets.only(bottom: 17),
          child: Row(
            children: [
              SizedBox(
                width: 75,
                child: Text(
                  item['range'],
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                  ),
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
                width: 25,
                child: Text(
                  '$count',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget popularJobsChart() {
    final maxApplications = popularJobs
        .map((item) => item['applications'] as int)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: popularJobs.map((job) {
        final count = job['applications'] as int;

        return Padding(
          padding: const EdgeInsets.only(bottom: 19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job['title'],
                      style: const TextStyle(
                        color: navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$count applications',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recruitment Analytics',
              style: TextStyle(
                color: navy,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Track your hiring performance and candidate activity.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 850
                    ? 4
                    : constraints.maxWidth >= 500
                        ? 2
                        : 1;

                const gap = 13.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: width,
                      child: statCard(
                        'Total Applications',
                        '248',
                        'Across all positions',
                        Icons.description_outlined,
                        blue,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: statCard(
                        'Shortlisted',
                        '85',
                        'Candidates selected',
                        Icons.check_circle_outline,
                        const Color(0xFF059669),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: statCard(
                        'Active Jobs',
                        '12',
                        'Currently accepting',
                        Icons.work_outline,
                        const Color(0xFF0D9488),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: statCard(
                        'Avg. ATS Score',
                        '78%',
                        'Across applicants',
                        Icons.analytics_outlined,
                        const Color(0xFFD97706),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 22),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 850;

                final applications = sectionCard(
                  title: 'Application Overview',
                  subtitle: 'Applications received over the last six months',
                  child: monthlyChart(),
                );

                final statuses = sectionCard(
                  title: 'Application Status',
                  subtitle: 'Distribution of candidate applications',
                  child: statusChart(),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: applications),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: statuses),
                    ],
                  );
                }

                return Column(
                  children: [
                    applications,
                    const SizedBox(height: 16),
                    statuses,
                  ],
                );
              },
            ),

            const SizedBox(height: 18),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 850;

                final scores = sectionCard(
                  title: 'ATS Score Distribution',
                  subtitle: 'Candidate scores grouped by matching percentage',
                  child: scoreChart(),
                );

                final jobs = sectionCard(
                  title: 'Popular Job Positions',
                  subtitle: 'Applications received by job position',
                  child: popularJobsChart(),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: scores),
                      const SizedBox(width: 16),
                      Expanded(child: jobs),
                    ],
                  );
                }

                return Column(
                  children: [
                    scores,
                    const SizedBox(height: 16),
                    jobs,
                  ],
                );
              },
            ),

            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.insights_outlined,
                    color: Color(0xFF9DB1FF),
                    size: 30,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recruitment Performance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Use ATS scores and application trends to identify '
                          'strong candidates and improve your hiring process.',
                          style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
