
import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  static const Color navy = Color(0xFF172554);
  static const Color blue = Color(0xFF4F6EF7);
  static const Color background = Color(0xFFF5F7FC);

  Widget statisticCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            value,
            style: const TextStyle(
              color: navy,
              fontSize: 27,
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
        ],
      ),
    );
  }

  Widget recentJobRow(Map<String, dynamic> job) {
    final status = job['status'] ?? 'Active';
    final statusColor = status == 'Active'
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.work_outline,
              color: blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job['title'] ?? 'Untitled Job',
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job['department'] ?? 'No department',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${job['applicants'] ?? 0} applicants',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 11,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget emptyJobsMessage() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 35),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.work_off_outlined,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 10),
            Text(
              'No jobs created yet',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Create your first job to see it here.',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AdminService().getJobs(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error loading dashboard:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Get actual jobs from Firestore.
        final jobs = snapshot.data!.docs.map((document) {
          return document.data();
        }).toList();

        final totalJobs = jobs.length;

        return Container(
          color: background,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back, Recruiter!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Here is what is happening with your recruitment today.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 25),

                // Dashboard statistics.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 850
                        ? 4
                        : constraints.maxWidth >= 550
                            ? 2
                            : 1;

                    const gap = 15.0;

                    final cardWidth =
                        (constraints.maxWidth -
                                (gap * (columns - 1))) /
                            columns;

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: statisticCard(
                            title: 'Total Jobs',
                            value: '$totalJobs',
                            subtitle: 'Actual posted vacancies',
                            icon: Icons.work_outline,
                            iconColor: blue,
                            iconBackground:
                                const Color(0xFFEEF2FF),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: statisticCard(
                            title: 'Candidates',
                            value: '0',
                            subtitle: 'Not connected yet',
                            icon: Icons.people_outline,
                            iconColor: const Color(0xFF0D9488),
                            iconBackground:
                                const Color(0xFFCCFBF1),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: statisticCard(
                            title: 'Pending Reviews',
                            value: '0',
                            subtitle: 'Not connected yet',
                            icon: Icons.pending_actions_outlined,
                            iconColor: const Color(0xFFD97706),
                            iconBackground:
                                const Color(0xFFFEF3C7),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: statisticCard(
                            title: 'Shortlisted',
                            value: '0',
                            subtitle: 'Not connected yet',
                            icon: Icons.how_to_reg_outlined,
                            iconColor: const Color(0xFF7C3AED),
                            iconBackground:
                                const Color(0xFFEDE9FE),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),

                // Create job banner.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Find your next great hire',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Create a job opening and let your resume screening system find suitable candidates.',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 15),
                            ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Select Create Job from the sidebar.',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.add,
                                size: 17,
                              ),
                              label: const Text('Create New Job'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF8FA5FF),
                                foregroundColor: navy,
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.person_search_outlined,
                        color: Color(0xFF8FA5FF),
                        size: 65,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Actual recent jobs from Firestore.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFFE9EDF5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Job Postings',
                        style: TextStyle(
                          color: navy,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Your latest jobs created in the system',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(
                        color: Color(0xFFE9EDF5),
                      ),

                      if (jobs.isEmpty)
                        emptyJobsMessage()
                      else
                        ...jobs.take(5).map((job) {
                          return Column(
                            children: [
                              recentJobRow(job),
                              const Divider(
                                color: Color(0xFFF1F5F9),
                              ),
                            ],
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
