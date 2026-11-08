import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';

const Color _navy = Color(0xFF172554);
const Color _blue = Color(0xFF4F6EF7);
const Color _green = Color(0xFF059669);
const Color _amber = Color(0xFFD97706);
const Color _red = Color(0xFFDC6262);
const Color _muted = Color(0xFF64748B);
const Color _faint = Color(0xFF94A3B8);
const Color _border = Color(0xFFE9EDF5);

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String _today() {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final now = DateTime.now();
  return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
}

String _timeAgo(DateTime time) {
  final difference = DateTime.now().difference(time.toLocal());

  if (difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  if (difference.inDays < 30) return '${difference.inDays} d ago';
  return '${(difference.inDays / 30).floor()} mo ago';
}

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key, this.onNavigate});

  /// Asks the dashboard to open a page:
  /// 1 Create Job, 2 Manage Jobs, 3 Candidates.
  final ValueChanged<int>? onNavigate;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  // Created once, so rebuilding the dashboard does not restart the stream.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _jobsStream =
      AdminService().getJobs();

  void _open(int index) => widget.onNavigate?.call(index);

  // ------------------------------------------------------------- widgets

  Widget _header(bool isPhone) {
    final name = (FirebaseAuth.instance.currentUser?.displayName ?? '')
        .trim()
        .split(' ')
        .first;
    final who = name.isEmpty ? 'Recruiter' : name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _today().toUpperCase(),
          style: const TextStyle(
            color: _faint,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_greeting()}, $who',
          style: TextStyle(
            fontSize: isPhone ? 24 : 27,
            fontWeight: FontWeight.w800,
            color: _navy,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Here is what is happening with your recruitment today.',
          style: TextStyle(fontSize: 13, color: _muted, height: 1.4),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
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
              color: _navy,
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
              color: _navy,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _faint, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _statGrid(List<Widget> Function(double width, bool compact) build,
      double contentWidth) {
    final columns = contentWidth >= 760 ? 4 : 2;
    const gap = 12.0;
    final width = (contentWidth - gap * (columns - 1)) / columns;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: build(width, contentWidth < 560),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _hero(bool isPhone) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF172554), Color(0xFF2B3F8C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: _circle(130, Colors.white.withValues(alpha: 0.06)),
              ),
              Positioned(
                right: 40,
                bottom: -45,
                child: _circle(100, _blue.withValues(alpha: 0.25)),
              ),
              Padding(
                padding: EdgeInsets.all(isPhone ? 20 : 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 13,
                            color: Color(0xFF8FA5FF),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'AI SCREENING',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Find your next great hire',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isPhone ? 21 : 24,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a job and the AI instantly matches it with '
                      'every screened resume.',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Both buttons share one size and alignment: stacked and
                    // full width on phones, side by side on larger screens.
                    Builder(
                      builder: (_) {
                        final buttonSize = Size(
                          isPhone ? double.infinity : 190,
                          48,
                        );

                        final createButton = FilledButton.icon(
                          onPressed: () => _open(1),
                          icon: const Icon(Icons.add_rounded, size: 19),
                          label: const Text('Create new job'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF8FA5FF),
                            foregroundColor: _navy,
                            minimumSize: buttonSize,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );

                        final viewButton = OutlinedButton.icon(
                          onPressed: () => _open(3),
                          icon: const Icon(Icons.people_outline, size: 18),
                          label: const Text('View candidates'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: buttonSize,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );

                        if (isPhone) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              createButton,
                              const SizedBox(height: 10),
                              viewButton,
                            ],
                          );
                        }

                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [createButton, viewButton],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget? _matchChip(Map<String, dynamic> job) {
    final status = job['matchStatus'];

    if (status == 'processing') return _chip('Matching...', _amber);
    if (status == 'failed') return _chip('Match failed', _red);

    if (status == 'completed') {
      final evaluated = job['matchEvaluated'];
      if (evaluated is num) {
        return _chip('${evaluated.toInt()} resumes matched', _blue);
      }
    }

    return null;
  }

  Widget _jobRow(Map<String, dynamic> job) {
    final status = (job['status'] ?? 'Active').toString();
    final statusColor = status == 'Active' ? _green : _red;

    final created = job['createdAt'];
    final details = [
      (job['department'] ?? '').toString().trim(),
      (job['jobType'] ?? '').toString().trim(),
      if (created is Timestamp) _timeAgo(created.toDate()),
    ].where((part) => part.isNotEmpty).join('  •  ');

    final matchChip = _matchChip(job);

    return InkWell(
      onTap: () => _open(2),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.work_outline, color: _blue, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (job['title'] ?? 'Untitled Job').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    details.isEmpty ? 'No details' : details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  if (matchChip != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: matchChip,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _chip(status, statusColor),
          ],
        ),
      ),
    );
  }

  Widget _emptyJobs() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.work_off_outlined,
                size: 30,
                color: _blue,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No jobs created yet',
              style: TextStyle(
                color: _navy,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Create your first job to see it here.',
              style: TextStyle(color: _faint, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _open(1),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create a job'),
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentJobs(List<Map<String, dynamic>> jobs) {
    final shown = jobs.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent job postings',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Your latest jobs in the system',
                      style: TextStyle(color: _faint, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (jobs.isNotEmpty)
                TextButton(
                  onPressed: () => _open(2),
                  child: const Text('View all'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (shown.isEmpty)
            _emptyJobs()
          else
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _jobRow(shown[i]),
            ],
        ],
      ),
    );
  }

  Widget _errorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: _faint),
            const SizedBox(height: 12),
            const Text(
              'Could not load the dashboard',
              style: TextStyle(
                color: _navy,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _jobsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorState(snapshot.error!);
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data!.docs.map((doc) => doc.data()).toList();

        // Real numbers taken from the jobs themselves.
        final total = jobs.length;
        final active =
            jobs.where((job) => (job['status'] ?? 'Active') == 'Active').length;
        final closed = jobs.where((job) => job['status'] == 'Closed').length;
        final evaluations = jobs.fold<int>(0, (sum, job) {
          final value = job['matchEvaluated'];
          return sum + (value is num ? value.toInt() : 0);
        });

        return Container(
          color: const Color(0xFFF5F7FC),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isPhone = constraints.maxWidth < 600;
              final padding = isPhone ? 16.0 : 25.0;
              final contentWidth = (constraints.maxWidth - padding * 2)
                  .clamp(0.0, 1100.0)
                  .toDouble();

              return SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(isPhone),
                        SizedBox(height: isPhone ? 18 : 24),
                        _statGrid(
                          (width, compact) => [
                            SizedBox(
                              width: width,
                              child: _statCard(
                                title: 'Total jobs',
                                value: '$total',
                                subtitle: 'All posted vacancies',
                                icon: Icons.work_outline,
                                color: _blue,
                                compact: compact,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _statCard(
                                title: 'Active jobs',
                                value: '$active',
                                subtitle: 'Open for applications',
                                icon: Icons.check_circle_outline,
                                color: _green,
                                compact: compact,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _statCard(
                                title: 'Closed jobs',
                                value: '$closed',
                                subtitle: 'No longer hiring',
                                icon: Icons.lock_outline,
                                color: _amber,
                                compact: compact,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _statCard(
                                title: 'AI evaluations',
                                value: '$evaluations',
                                subtitle: 'Resumes scored for jobs',
                                icon: Icons.auto_awesome_outlined,
                                color: const Color(0xFF7C3AED),
                                compact: compact,
                              ),
                            ),
                          ],
                          contentWidth,
                        ),
                        SizedBox(height: isPhone ? 18 : 24),
                        _hero(isPhone),
                        SizedBox(height: isPhone ? 18 : 24),
                        _recentJobs(jobs),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
