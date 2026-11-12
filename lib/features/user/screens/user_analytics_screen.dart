import 'package:flutter/material.dart';

import '../services/user_insights_controller.dart';
import '../services/user_insights_service.dart';
import '../widgets/user_ui.dart';

/// Analytics: how this candidate's resume scored against the open jobs.
class UserAnalyticsScreen extends StatefulWidget {
  const UserAnalyticsScreen({
    super.key,
    required this.insights,
    required this.onGoHome,
    required this.onGoJobs,
  });

  final UserInsightsController insights;
  final VoidCallback onGoHome;
  final VoidCallback onGoJobs;

  @override
  State<UserAnalyticsScreen> createState() => _UserAnalyticsScreenState();
}

class _UserAnalyticsScreenState extends State<UserAnalyticsScreen> {
  String _filter = 'all'; // all | highly_eligible | potential | low_match
  bool _showAll = false;

  static const int _collapsedRows = 6;

  @override
  Widget build(BuildContext context) {
    return UserPage(
      onRefresh: () => widget.insights.load(silent: true),
      builder: (context, compact, contentWidth) {
        return ListenableBuilder(
          listenable: widget.insights,
          builder: (context, _) {
            final data = widget.insights.data;

            Widget body;
            if (data == null && widget.insights.loading) {
              body = _loading();
            } else if (data == null) {
              body = _error(widget.insights.error);
            } else if (!data.hasProfile) {
              body = _noResume();
            } else if (data.matches.isEmpty) {
              body = _noMatches(data);
            } else {
              body = _full(data, compact, contentWidth);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(compact),
                SizedBox(height: compact ? 16 : 20),
                body,
              ],
            );
          },
        );
      },
    );
  }

  Widget _header(bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your match insights',
          style: TextStyle(
            fontSize: compact ? 24 : 27,
            fontWeight: FontWeight.w800,
            color: UserUi.navy,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'See how well your resume fits the jobs that are open right now.',
          style: TextStyle(color: UserUi.muted, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- states

  Widget _loading() {
    return const Column(
      children: [
        UserCard(
          child: Row(
            children: [
              SkeletonBar(width: 84, height: 84),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBar(width: 170, height: 18),
                    SizedBox(height: 10),
                    SkeletonBar(height: 12),
                    SizedBox(height: 8),
                    SkeletonBar(width: 120, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        UserCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBar(width: 140, height: 16),
              SizedBox(height: 16),
              SkeletonBar(height: 14),
              SizedBox(height: 12),
              SkeletonBar(height: 14),
              SizedBox(height: 12),
              SkeletonBar(width: 220, height: 14),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stateCard({
    required IconData icon,
    required String title,
    required String text,
    required String buttonLabel,
    required VoidCallback onPressed,
    Color color = UserUi.blue,
  }) {
    return UserCard(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: UserUi.navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: UserUi.muted,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: UserUi.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(190, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  Widget _error(String? message) {
    return _stateCard(
      icon: Icons.cloud_off_rounded,
      color: UserUi.red,
      title: 'Could not load your insights',
      text: message ?? 'Something went wrong. Please try again.',
      buttonLabel: 'Try again',
      onPressed: () => widget.insights.load(),
    );
  }

  Widget _noResume() {
    return _stateCard(
      icon: Icons.description_outlined,
      title: 'Upload your resume first',
      text:
          'Your match insights are built from your resume. Upload it on the '
          'Home tab and the AI will analyse it.',
      buttonLabel: 'Go to Home',
      onPressed: widget.onGoHome,
    );
  }

  Widget _noMatches(CandidateInsights data) {
    final jobs = data.jobsTotal;

    return _stateCard(
      icon: Icons.hourglass_bottom_rounded,
      color: UserUi.amber,
      title: 'No match results yet',
      text:
          'Your resume is ready. Match scores appear once a recruiter runs AI '
          'matching for a job. '
          '${jobs == 0 ? 'There are no open jobs at the moment.' : '$jobs open ${jobs == 1 ? 'job is' : 'jobs are'} waiting to be evaluated.'}',
      buttonLabel: 'Browse jobs',
      onPressed: widget.onGoJobs,
    );
  }

  // ------------------------------------------------------------- full view

  Widget _full(CandidateInsights data, bool compact, double contentWidth) {
    final wide = contentWidth >= 800;
    final gap = compact ? 14.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hero(data, compact),
        SizedBox(height: gap),
        _statGrid(data, contentWidth, compact),
        SizedBox(height: gap),
        _overviewCard(data, compact),
        SizedBox(height: gap),
        _pair(
          wide: wide,
          gap: gap,
          first: _skillsCard(
            title: 'Your strongest skills',
            subtitle: 'Skills that matched the most jobs',
            icon: Icons.bolt_rounded,
            color: UserUi.green,
            skills: data.topSkills,
            empty: 'No matched skills yet.',
            compact: compact,
          ),
          second: _skillsCard(
            title: 'Skills to add next',
            subtitle: 'Most often missing from your resume',
            icon: Icons.school_outlined,
            color: UserUi.amber,
            skills: data.skillGaps,
            empty: 'Nothing missing. Great coverage!',
            compact: compact,
          ),
        ),
        SizedBox(height: gap),
        _matchesCard(data, compact),
        SizedBox(height: gap),
        _footnote(data),
      ],
    );
  }

  Widget _pair({
    required bool wide,
    required double gap,
    required Widget first,
    required Widget second,
  }) {
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          SizedBox(width: gap),
          Expanded(child: second),
        ],
      );
    }

    return Column(children: [first, SizedBox(height: gap), second]);
  }

  // ------------------------------------------------------------------ hero

  Widget _hero(CandidateInsights data, bool compact) {
    final average = data.summary.averageScore ?? 0;
    final best = data.matches.first;
    final matched = data.matchedJobs;

    final headline = matched == 0
        ? 'No strong matches yet'
        : 'Matched with $matched ${matched == 1 ? 'job' : 'jobs'}';

    final sub = matched == 0
        ? 'Add the missing skills below to raise your scores.'
        : '${data.summary.highlyEligible} highly eligible · '
              '${data.summary.potential} high potential';

    final ringSize = compact ? 86.0 : 100.0;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [UserUi.navy, Color(0xFF2A3F94)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Row(
            children: [
              ScoreRing(
                value: average,
                color: const Color(0xFF8FA5FF),
                trackColor: Colors.white.withValues(alpha: 0.14),
                size: ringSize,
                strokeWidth: compact ? 8 : 9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${average.round()}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 22 : 26,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'average',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 16 : 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESUME MATCH',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10.5,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      headline,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 20 : 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sub,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events_outlined,
                            size: 15,
                            color: Color(0xFFFFD166),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Best: ${best.jobTitle} · ${best.score.round()}%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
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
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- stats

  Widget _statGrid(CandidateInsights data, double contentWidth, bool compact) {
    final columns = contentWidth >= 760 ? 4 : 2;
    const gap = 12.0;
    final width = (contentWidth - gap * (columns - 1)) / columns;
    final s = data.summary;

    Widget cell(
      String label,
      String value,
      String caption,
      IconData icon,
      Color color,
    ) {
      return SizedBox(
        width: width,
        child: Container(
          padding: EdgeInsets.all(compact ? 14 : 18),
          decoration: UserUi.card(),
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
              SizedBox(height: compact ? 12 : 14),
              Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 26 : 30,
                  fontWeight: FontWeight.w800,
                  color: UserUi.navy,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: UserUi.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        cell(
          'Highly eligible',
          '${s.highlyEligible}',
          '${data.highlyEligibleMin}%+ match',
          Icons.verified_rounded,
          UserUi.green,
        ),
        cell(
          'High potential',
          '${s.potential}',
          '${data.potentialMin}-${data.highlyEligibleMin - 1}% match',
          Icons.trending_up_rounded,
          UserUi.amber,
        ),
        cell(
          'Low match',
          '${s.lowMatch}',
          'Below ${data.potentialMin}%',
          Icons.remove_circle_outline_rounded,
          UserUi.slate,
        ),
        cell(
          'Jobs evaluated',
          '${data.jobsEvaluated}',
          'of ${data.jobsTotal} open',
          Icons.fact_check_outlined,
          UserUi.blue,
        ),
      ],
    );
  }

  // -------------------------------------------------------------- overview

  Widget _overviewCard(CandidateInsights data, bool compact) {
    final s = data.summary;
    final total = s.total == 0 ? 1 : s.total;

    final bands = <({String key, int count})>[
      (key: 'highly_eligible', count: s.highlyEligible),
      (key: 'potential', count: s.potential),
      (key: 'low_match', count: s.lowMatch),
    ];

    return UserCard(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            icon: Icons.donut_small_rounded,
            title: 'Match overview',
            subtitle: 'How your jobs split across the three bands',
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                for (final band in bands)
                  if (band.count > 0)
                    Expanded(
                      flex: band.count,
                      child: Container(
                        height: compact ? 14 : 16,
                        margin: const EdgeInsets.only(right: 2),
                        color: UserUi.eligibilityColor(band.key),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final band in bands)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: UserUi.eligibilityColor(band.key),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      UserUi.eligibilityLabel(band.key),
                      style: const TextStyle(color: UserUi.muted, fontSize: 13),
                    ),
                  ),
                  Text(
                    '${band.count}',
                    style: const TextStyle(
                      color: UserUi.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${(band.count / total * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: UserUi.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- skills

  Widget _skillsCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<SkillCount> skills,
    required String empty,
    required bool compact,
  }) {
    final maxCount = skills.isEmpty
        ? 1
        : skills.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return UserCard(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: icon,
            title: title,
            subtitle: subtitle,
            color: color,
          ),
          const SizedBox(height: 18),
          if (skills.isEmpty)
            Text(
              empty,
              style: const TextStyle(color: UserUi.muted, fontSize: 13),
            )
          else
            for (final item in skills)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.skill,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: UserUi.navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.count} ${item.count == 1 ? 'job' : 'jobs'}',
                          style: const TextStyle(
                            color: UserUi.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    MiniBar(value: item.count / maxCount, color: color),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- matches

  Widget _matchesCard(CandidateInsights data, bool compact) {
    final s = data.summary;

    final filtered = data.matches.where((m) {
      return _filter == 'all' || m.eligibility == _filter;
    }).toList();

    final shown = _showAll
        ? filtered
        : filtered.take(_collapsedRows).toList();

    return UserCard(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.work_outline,
            title: 'Job matches',
            subtitle: 'Tap a job to see why you scored this way',
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('all', 'All', data.matches.length, UserUi.blue),
                _filterChip(
                  'highly_eligible',
                  'Highly eligible',
                  s.highlyEligible,
                  UserUi.green,
                ),
                _filterChip(
                  'potential',
                  'High potential',
                  s.potential,
                  UserUi.amber,
                ),
                _filterChip('low_match', 'Low match', s.lowMatch, UserUi.slate),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No jobs in this band.',
                  style: TextStyle(color: UserUi.muted),
                ),
              ),
            )
          else
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: UserUi.border),
              _matchRow(shown[i]),
            ],
          if (filtered.length > _collapsedRows)
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                style: TextButton.styleFrom(foregroundColor: UserUi.blue),
                child: Text(
                  _showAll ? 'Show fewer' : 'Show all ${filtered.length} jobs',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label, int count, Color color) {
    final selected = _filter == key;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() {
          _filter = key;
          _showAll = false;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : UserUi.border),
          ),
          child: Text(
            '$label · $count',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : UserUi.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _matchRow(MyJobMatch match) {
    final color = UserUi.eligibilityColor(match.eligibility);
    final meta = [
      match.department,
      match.location,
    ].whereType<String>().join(' · ');

    return InkWell(
      onTap: () => _showDetail(match),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            ScoreRing(
              value: match.score,
              color: color,
              size: 52,
              strokeWidth: 5.5,
              child: Text(
                '${match.score.round()}',
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
                  Text(
                    match.jobTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: UserUi.navy,
                      fontSize: 14.5,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: UserUi.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Pill(
                    text: UserUi.eligibilityLabel(match.eligibility),
                    color: color,
                    icon: UserUi.eligibilityIcon(match.eligibility),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: UserUi.faint),
          ],
        ),
      ),
    );
  }

  Widget _footnote(CandidateInsights data) {
    final pending = data.notEvaluated;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UserUi.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UserUi.blue.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: UserUi.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Scores come from AI comparing your resume with each job\'s '
              'requirements. ${data.highlyEligibleMin}%+ is highly eligible '
              'and ${data.potentialMin}%+ is high potential. They update when '
              'a recruiter re-runs matching or you replace your resume.'
              '${pending > 0 ? ' $pending open ${pending == 1 ? 'job has' : 'jobs have'} not been evaluated yet.' : ''}',
              style: const TextStyle(
                color: UserUi.body,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- detail

  static const List<(String, String)> _breakdownLabels = [
    ('skills', 'Skills'),
    ('experience', 'Experience'),
    ('title', 'Job title fit'),
    ('education', 'Education'),
    ('impact', 'Impact & growth'),
    ('semantic', 'Resume similarity'),
  ];

  String _years(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  void _showDetail(MyJobMatch match) {
    final color = UserUi.eligibilityColor(match.eligibility);
    final meta = [
      match.department,
      match.location,
      match.jobType,
    ].whereType<String>().join(' • ');

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
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.92;

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
                        match.jobTitle,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: UserUi.navy,
                          height: 1.2,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          meta,
                          style: const TextStyle(color: UserUi.muted),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Score
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: color.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          children: [
                            ScoreRing(
                              value: match.score,
                              color: color,
                              size: 76,
                              strokeWidth: 7,
                              child: Text(
                                '${match.score.round()}%',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Pill(
                                    text: UserUi.eligibilityLabel(
                                      match.eligibility,
                                    ),
                                    color: color,
                                    icon: UserUi.eligibilityIcon(
                                      match.eligibility,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (match.scoredAt != null)
                                    Text(
                                      'Evaluated ${UserUi.dateText(match.scoredAt!)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: UserUi.muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (match.summary.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          match.summary,
                          style: const TextStyle(
                            color: UserUi.body,
                            fontSize: 13.5,
                            height: 1.55,
                          ),
                        ),
                      ],

                      // Breakdown
                      _sheetTitle('Score breakdown'),
                      for (final item in _breakdownLabels)
                        if (match.breakdown[item.$1] != null)
                          _breakdownRow(item.$2, match.breakdown[item.$1]!),

                      if (match.totalYears > 0 ||
                          match.mustHaveCoverage > 0) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (match.totalYears > 0)
                              Pill(
                                text:
                                    '${_years(match.relevantYears)} of ${_years(match.totalYears)} yrs relevant',
                                color: UserUi.teal,
                                icon: Icons.work_history_outlined,
                              ),
                            if (match.mustHaveCoverage > 0)
                              Pill(
                                text:
                                    '${(match.mustHaveCoverage * 100).round()}% of required skills',
                                color: UserUi.blue,
                                icon: Icons.rule_rounded,
                              ),
                          ],
                        ),
                      ],

                      if (match.matchedSkills.isNotEmpty) ...[
                        _sheetTitle('Skills you have'),
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
                        _sheetTitle('Skills to add'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final skill in match.missingSkills)
                              SkillChip(text: skill, color: UserUi.amber),
                          ],
                        ),
                      ],

                      if (match.strengths.isNotEmpty) ...[
                        _sheetTitle('Strengths'),
                        for (final text in match.strengths)
                          _bullet(text, UserUi.green),
                      ],

                      if (match.gaps.isNotEmpty) ...[
                        _sheetTitle('Gaps'),
                        for (final text in match.gaps)
                          _bullet(text, UserUi.amber),
                      ],

                      const SizedBox(height: 12),
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
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      widget.onGoJobs();
                    },
                    icon: const Icon(Icons.work_outline, size: 19),
                    label: const Text('See this job'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UserUi.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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

  Widget _sheetTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: UserUi.navy,
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, double value) {
    final color = value >= 75
        ? UserUi.green
        : (value >= 60 ? UserUi.amber : UserUi.slate);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: UserUi.body, fontSize: 13),
                ),
              ),
              Text(
                '${value.round()}%',
                style: const TextStyle(
                  color: UserUi.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          MiniBar(value: value / 100, color: color, height: 7),
        ],
      ),
    );
  }

  Widget _bullet(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: UserUi.body,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
