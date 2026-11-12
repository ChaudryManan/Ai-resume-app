import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/user_actions.dart';
import '../services/user_insights_controller.dart';
import '../services/user_insights_service.dart';
import '../services/user_job_service.dart';
import '../widgets/user_ui.dart';

/// Jobs: every open job, searchable, with the candidate's own match score.
class UserJobsScreen extends StatefulWidget {
  const UserJobsScreen({
    super.key,
    required this.actions,
    required this.insights,
  });

  final UserActions actions;
  final UserInsightsController insights;

  @override
  State<UserJobsScreen> createState() => _UserJobsScreenState();
}

class _UserJobsScreenState extends State<UserJobsScreen> {
  final UserJobService _service = UserJobService();
  final TextEditingController _search = TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _jobsStream = _service
      .getJobs();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _applicationsStream =
      _service.getMyApplications();

  String _query = '';
  String _filter = 'all'; // all | open | applied

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UserPage(
      builder: (context, compact, contentWidth) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _jobsStream,
          builder: (context, jobSnapshot) {
            if (jobSnapshot.hasError) {
              return _message(
                Icons.error_outline_rounded,
                'Unable to load jobs.',
                'Check your connection and try again.',
              );
            }

            if (jobSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(color: UserUi.blue),
                ),
              );
            }

            // Only active jobs are shown to candidates.
            final activeJobs = (jobSnapshot.data?.docs ?? []).where((doc) {
              return (doc.data()['status'] ?? 'Active') == 'Active';
            }).toList();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _applicationsStream,
              builder: (context, applicationSnapshot) {
                if (applicationSnapshot.hasError) {
                  return _message(
                    Icons.error_outline_rounded,
                    'Unable to load applications.',
                    'Check your connection and try again.',
                  );
                }

                final applied = (applicationSnapshot.data?.docs ?? [])
                    .map((doc) => doc.data()['jobId'].toString())
                    .toSet();

                return _content(
                  compact: compact,
                  contentWidth: contentWidth,
                  activeJobs: activeJobs,
                  applied: applied,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _content({
    required bool compact,
    required double contentWidth,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> activeJobs,
    required Set<String> applied,
  }) {
    final query = _query.toLowerCase();

    bool matchesSearch(Map<String, dynamic> data) {
      return (data['title'] ?? '').toString().toLowerCase().contains(query) ||
          (data['department'] ?? '').toString().toLowerCase().contains(query) ||
          (data['location'] ?? '').toString().toLowerCase().contains(query);
    }

    final appliedCount = activeJobs
        .where((doc) => applied.contains(doc.id))
        .length;

    final visible = activeJobs.where((doc) {
      if (!matchesSearch(doc.data())) return false;
      if (_filter == 'applied') return applied.contains(doc.id);
      if (_filter == 'open') return !applied.contains(doc.id);
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore opportunities',
          style: TextStyle(
            fontSize: compact ? 24 : 27,
            fontWeight: FontWeight.w800,
            color: UserUi.navy,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Find a role that fits your skills and apply in one tap.',
          style: TextStyle(color: UserUi.muted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: compact
                ? 'Search title, department, location'
                : 'Search by job title, department or location...',
            hintMaxLines: 1,
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.search_rounded, color: UserUi.blue),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: UserUi.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: UserUi.blue, width: 1.6),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: UserUi.border),
            ),
          ),
        ),

        const SizedBox(height: 14),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('all', 'All', activeJobs.length),
              const SizedBox(width: 8),
              _filterChip('open', 'Not applied', activeJobs.length - appliedCount),
              const SizedBox(width: 8),
              _filterChip('applied', 'Applied', appliedCount),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (visible.isEmpty)
          _empty()
        else
          ListenableBuilder(
            listenable: widget.insights,
            builder: (context, _) {
              return _grid(
                contentWidth: contentWidth,
                compact: compact,
                jobs: visible,
                applied: applied,
              );
            },
          ),
      ],
    );
  }

  Widget _filterChip(String key, String label, int count) {
    final selected = _filter == key;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _filter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? UserUi.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? UserUi.blue : UserUi.border),
        ),
        child: Text(
          '$label · $count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : UserUi.muted,
          ),
        ),
      ),
    );
  }

  Widget _message(IconData icon, String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: UserUi.faint),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: UserUi.navy,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(color: UserUi.muted)),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return UserCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.work_off_outlined, size: 44, color: UserUi.faint),
          const SizedBox(height: 14),
          const Text(
            'No jobs found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: UserUi.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _query.isNotEmpty || _filter != 'all'
                ? 'Nothing matches your search or filter.'
                : 'There are currently no open jobs.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: UserUi.muted),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ list

  Widget _grid({
    required double contentWidth,
    required bool compact,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs,
    required Set<String> applied,
  }) {
    const gap = 14.0;
    final twoColumns = contentWidth >= 900;
    final width = twoColumns ? (contentWidth - gap) / 2 : contentWidth;
    final insights = widget.insights.data;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: jobs.map((doc) {
        return SizedBox(
          width: width,
          child: _jobCard(
            job: doc.data(),
            jobId: doc.id,
            hasApplied: applied.contains(doc.id),
            match: insights?.matchFor(doc.id),
            compact: compact,
          ),
        );
      }).toList(),
    );
  }

  Widget _jobCard({
    required Map<String, dynamic> job,
    required String jobId,
    required bool hasApplied,
    required MyJobMatch? match,
    required bool compact,
  }) {
    final title = job['title']?.toString() ?? 'Untitled Job';
    final department = job['department']?.toString() ?? '';
    final location = job['location']?.toString() ?? 'Not specified';
    final jobType = job['jobType']?.toString() ?? '';
    final salary = job['salary']?.toString() ?? '';

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: UserUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: UserUi.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.work_outline,
                  color: UserUi.blue,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 16.5 : 17.5,
                        fontWeight: FontWeight.w800,
                        color: UserUi.navy,
                        height: 1.25,
                      ),
                    ),
                    if (department.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        department,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: UserUi.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasApplied) ...[
                const SizedBox(width: 8),
                const Pill(
                  text: 'Applied',
                  color: UserUi.green,
                  icon: Icons.check_rounded,
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _jobInfo(Icons.location_on_outlined, location),
              if (jobType.isNotEmpty) _jobInfo(Icons.access_time_rounded, jobType),
              if (salary.isNotEmpty) _jobInfo(Icons.payments_outlined, salary),
            ],
          ),

          // How this candidate's resume scored for the job.
          if (match != null) ...[
            const SizedBox(height: 14),
            _matchStrip(match),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1, color: UserUi.border),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showDetails(
                    job: job,
                    jobId: jobId,
                    hasApplied: hasApplied,
                    match: match,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    foregroundColor: UserUi.blue,
                    side: BorderSide(color: UserUi.blue.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('View details'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: hasApplied
                      ? null
                      : () => widget.actions.applyForJob(context, jobId, title),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UserUi.blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: UserUi.green.withValues(alpha: 0.10),
                    disabledForegroundColor: UserUi.green,
                    elevation: 0,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(hasApplied ? 'Applied' : 'Apply now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _matchStrip(MyJobMatch match) {
    final color = UserUi.eligibilityColor(match.eligibility);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          ScoreRing(
            value: match.score,
            color: color,
            size: 42,
            strokeWidth: 5,
            child: Text(
              '${match.score.round()}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  UserUi.eligibilityLabel(match.eligibility),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Your resume match for this job',
                  style: const TextStyle(fontSize: 12, color: UserUi.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: UserUi.muted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: UserUi.muted),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- details

  // The Apply button stays pinned at the bottom, so on a phone you don't
  // have to scroll to the end to apply.
  void _showDetails({
    required Map<String, dynamic> job,
    required String jobId,
    required bool hasApplied,
    required MyJobMatch? match,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.9;
        final title = job['title']?.toString() ?? 'Job';

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: UserUi.navy,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        [job['department'], job['location']]
                            .where((e) => e != null && e.toString().isNotEmpty)
                            .join(' • '),
                        style: const TextStyle(color: UserUi.muted),
                      ),
                      if (match != null) ...[
                        const SizedBox(height: 18),
                        _sheetMatch(match),
                      ],
                      const SizedBox(height: 22),
                      _section(
                        'Job description',
                        job['description']?.toString() ?? 'Not provided',
                      ),
                      _section(
                        'Responsibilities',
                        job['responsibilities']?.toString() ?? 'Not provided',
                      ),
                      _section('Required skills', _skills(job['skills'])),
                      _section(
                        'Education',
                        job['education']?.toString() ?? 'Not specified',
                      ),
                      _section(
                        'Experience',
                        job['experience']?.toString() ?? 'Not specified',
                      ),
                      _section(
                        'Salary',
                        job['salary']?.toString() ?? 'Not specified',
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: UserUi.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: ElevatedButton(
                    onPressed: hasApplied
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            widget.actions.applyForJob(context, jobId, title);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UserUi.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      hasApplied ? 'Already applied' : 'Apply for this job',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetMatch(MyJobMatch match) {
    final color = UserUi.eligibilityColor(match.eligibility);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScoreRing(
                value: match.score,
                color: color,
                size: 58,
                strokeWidth: 6,
                child: Text(
                  '${match.score.round()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your match',
                      style: TextStyle(
                        fontSize: 12,
                        color: UserUi.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      UserUi.eligibilityLabel(match.eligibility),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (match.matchedSkills.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Skills you have',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: UserUi.navy,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in match.matchedSkills)
                  SkillChip(
                    text: skill,
                    color: UserUi.green,
                    icon: Icons.check_rounded,
                  ),
              ],
            ),
          ],
          if (match.missingSkills.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Skills to add',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: UserUi.navy,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in match.missingSkills)
                  SkillChip(text: skill, color: UserUi.amber),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: UserUi.navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(height: 1.5, color: UserUi.body),
          ),
        ],
      ),
    );
  }

  String _skills(dynamic skills) {
    if (skills is List) return skills.join(', ');

    if (skills == null || skills.toString().isEmpty) return 'Not specified';

    return skills.toString();
  }
}
