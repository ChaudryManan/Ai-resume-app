import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/user_actions.dart';
import '../services/user_insights_controller.dart';
import '../services/user_insights_service.dart';
import '../services/user_job_service.dart';
import '../widgets/user_ui.dart';

/// Home: welcome, resume upload and the profile the AI built from the resume.
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({
    super.key,
    required this.actions,
    required this.insights,
    required this.onNavigate,
  });

  final UserActions actions;
  final UserInsightsController insights;
  final ValueChanged<int> onNavigate;

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final UserJobService _service = UserJobService();

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _resumeStream =
      _service.getMyResume();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _jobsStream = _service
      .getJobs();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _applicationsStream =
      _service.getMyApplications();

  String get _name {
    final name = FirebaseAuth.instance.currentUser?.displayName;

    if (name == null || name.trim().isEmpty) return 'Candidate';

    return name.trim();
  }

  @override
  Widget build(BuildContext context) {
    return UserPage(
      onRefresh: () => widget.insights.load(silent: true),
      builder: (context, compact, contentWidth) {
        final wide = contentWidth >= 900;

        final profile = _ProfileCard(
          insights: widget.insights,
          fallbackName: _name,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hero(compact),
            const SizedBox(height: 14),
            _stats(),
            SizedBox(height: compact ? 16 : 20),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _resumeCard(compact),
                        const SizedBox(height: 16),
                        _nextSteps(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: profile),
                ],
              )
            else ...[
              _resumeCard(compact),
              const SizedBox(height: 16),
              profile,
              const SizedBox(height: 16),
              _nextSteps(),
            ],
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------------ hero

  Widget _hero(bool compact) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(compact ? 20 : 26),
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
            right: -46,
            top: -56,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -62,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: UserUi.blue.withValues(alpha: 0.28),
              ),
            ),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: compact ? 26 : 30,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                child: Text(
                  UserUi.initialOf(_name),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 22 : 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WELCOME BACK',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10.5,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 21 : 25,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Keep your resume up to date and see how well it '
                      'matches open jobs.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12.5,
                        height: 1.45,
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

  Widget _stats() {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _jobsStream,
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.where((doc) {
                return (doc.data()['status'] ?? 'Active') == 'Active';
              }).length;

              return _miniStat(
                icon: Icons.work_outline,
                color: UserUi.teal,
                value: count?.toString() ?? '–',
                label: 'Open jobs',
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _applicationsStream,
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length;

              return _miniStat(
                icon: Icons.description_outlined,
                color: UserUi.amber,
                value: count?.toString() ?? '–',
                label: 'Applications',
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.insights,
            builder: (context, _) {
              final best = widget.insights.data?.summary.bestScore;

              return _miniStat(
                icon: Icons.auto_awesome_rounded,
                color: UserUi.blue,
                value: best == null ? '–' : '${best.round()}%',
                label: 'Best match',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _miniStat({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: UserUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: UserUi.navy,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: UserUi.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- resume

  Widget _resumeCard(bool compact) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _resumeStream,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final hasResume = snapshot.hasData && snapshot.data!.exists;
        final data = hasResume ? snapshot.data!.data() : null;

        final fileName = data?['fileName']?.toString() ?? '';
        final status = data?['embeddingStatus']?.toString() ?? '';
        final uploadedAtRaw = data?['uploadedAt'];
        final uploadedAt = uploadedAtRaw is Timestamp
            ? uploadedAtRaw.toDate()
            : null;

        return UserCard(
          padding: EdgeInsets.all(compact ? 16 : 20),
          child: ValueListenableBuilder<bool>(
            valueListenable: widget.actions.uploading,
            builder: (context, uploading, _) {
              Widget? pill;

              if (uploading || status == 'processing') {
                pill = const Pill(
                  text: 'Analysing',
                  color: UserUi.blue,
                  icon: Icons.autorenew_rounded,
                );
              } else if (status == 'failed') {
                pill = const Pill(
                  text: 'Needs retry',
                  color: UserUi.red,
                  icon: Icons.error_outline_rounded,
                );
              } else if (hasResume && status == 'pending') {
                pill = const Pill(
                  text: 'Not analysed',
                  color: UserUi.amber,
                  icon: Icons.hourglass_bottom_rounded,
                );
              } else if (hasResume) {
                pill = const Pill(
                  text: 'Ready',
                  color: UserUi.green,
                  icon: Icons.check_circle_rounded,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(
                    icon: Icons.description_outlined,
                    title: 'My resume',
                    subtitle: 'PDF, up to 5 MB',
                    trailing: pill,
                  ),
                  const SizedBox(height: 16),
                  if (loading)
                    const SkeletonBar(height: 58)
                  else if (hasResume)
                    _fileBox(fileName, uploadedAt)
                  else
                    _emptyResumeBox(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (loading || uploading)
                          ? null
                          : () => widget.actions.pickAndUploadResume(context),
                      icon: uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: UserUi.blue,
                              ),
                            )
                          : Icon(
                              hasResume
                                  ? Icons.refresh_rounded
                                  : Icons.upload_file_rounded,
                              size: 20,
                            ),
                      label: Text(
                        uploading
                            ? 'Uploading & analysing...'
                            : (hasResume ? 'Replace resume' : 'Upload resume'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UserUi.blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: UserUi.blue.withValues(
                          alpha: 0.12,
                        ),
                        disabledForegroundColor: UserUi.blue,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _fileBox(String fileName, DateTime? uploadedAt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UserUi.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: UserUi.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: UserUi.red,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName.isEmpty ? 'Resume.pdf' : fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: UserUi.navy,
                    fontSize: 14,
                  ),
                ),
                if (uploadedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Uploaded ${UserUi.dateText(uploadedAt)}',
                    style: const TextStyle(fontSize: 12, color: UserUi.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyResumeBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: UserUi.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UserUi.blue.withValues(alpha: 0.22)),
      ),
      child: const Column(
        children: [
          Icon(Icons.cloud_upload_outlined, color: UserUi.blue, size: 30),
          SizedBox(height: 8),
          Text(
            'No resume yet',
            style: TextStyle(fontWeight: FontWeight.w800, color: UserUi.navy),
          ),
          SizedBox(height: 4),
          Text(
            'Upload your PDF resume to build your profile and apply for jobs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: UserUi.muted, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ next steps

  Widget _nextSteps() {
    return Column(
      children: [
        _actionTile(
          icon: Icons.work_outline,
          color: UserUi.teal,
          title: 'Browse open jobs',
          subtitle: 'Find a role and apply in one tap',
          onTap: () => widget.onNavigate(1),
        ),
        const SizedBox(height: 10),
        _actionTile(
          icon: Icons.insights_rounded,
          color: UserUi.blue,
          title: 'View my analytics',
          subtitle: 'See how your resume matches each job',
          onTap: () => widget.onNavigate(2),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: UserUi.card(),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: UserUi.navy,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: UserUi.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: UserUi.faint),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================== profile card

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({required this.insights, required this.fallbackName});

  final UserInsightsController insights;
  final String fallbackName;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _fullSummary = false;
  bool _allSkills = false;
  bool _allWork = false;

  static const int _skillLimit = 12;
  static const int _workLimit = 3;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.insights,
      builder: (context, _) {
        final data = widget.insights.data;

        if (data == null && widget.insights.loading) return _skeleton();

        if (data == null) return _error(widget.insights.error);

        final profile = data.profile;

        if (profile == null) return _empty();

        return _profile(profile);
      },
    );
  }

  Widget _skeleton() {
    return const UserCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBar(width: 56, height: 56),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBar(width: 160, height: 16),
                    SizedBox(height: 8),
                    SkeletonBar(width: 110, height: 12),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 22),
          SkeletonBar(height: 12),
          SizedBox(height: 10),
          SkeletonBar(height: 12),
          SizedBox(height: 10),
          SkeletonBar(width: 200, height: 12),
        ],
      ),
    );
  }

  Widget _error(String? message) {
    return UserCard(
      child: Column(
        children: [
          const SectionTitle(
            icon: Icons.person_outline,
            title: 'My profile',
            subtitle: 'Extracted from your resume by AI',
          ),
          const SizedBox(height: 18),
          const Icon(Icons.cloud_off_rounded, color: UserUi.faint, size: 34),
          const SizedBox(height: 10),
          Text(
            message ?? 'Could not load your profile.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: UserUi.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => widget.insights.load(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: UserUi.blue,
              side: BorderSide(color: UserUi.blue.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return const UserCard(
      child: Column(
        children: [
          SectionTitle(
            icon: Icons.person_outline,
            title: 'My profile',
            subtitle: 'Extracted from your resume by AI',
          ),
          SizedBox(height: 22),
          Icon(Icons.person_search_rounded, color: UserUi.faint, size: 40),
          SizedBox(height: 10),
          Text(
            'Your profile will appear here',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: UserUi.navy,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Upload your resume and our AI will build your profile from it: '
            'skills, experience and education.',
            textAlign: TextAlign.center,
            style: TextStyle(color: UserUi.muted, fontSize: 13, height: 1.45),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- the profile

  Widget _profile(CandidateProfileData p) {
    final name = p.fullName ?? widget.fallbackName;

    final shownSkills = _allSkills
        ? p.skills
        : p.skills.take(_skillLimit).toList();
    final hiddenSkills = p.skills.length - shownSkills.length;

    final shownWork = _allWork ? p.work : p.work.take(_workLimit).toList();
    final summary = p.summary;

    return UserCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            icon: Icons.person_outline,
            title: 'My profile',
            subtitle: 'Extracted from your resume by AI',
          ),
          const SizedBox(height: 18),

          // Identity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B93FF), UserUi.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(
                  UserUi.initialOf(name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: UserUi.navy,
                        height: 1.2,
                      ),
                    ),
                    if (p.title != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        p.title!,
                        style: const TextStyle(
                          color: UserUi.muted,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              if (p.location != null)
                _info(Icons.location_on_outlined, p.location!),
              if (p.email != null) _info(Icons.mail_outline_rounded, p.email!),
              if (p.phone != null) _info(Icons.phone_outlined, p.phone!),
              if (p.totalExperience != null)
                Pill(
                  text: '${p.totalExperience} experience',
                  color: UserUi.teal,
                  icon: Icons.work_history_outlined,
                ),
            ],
          ),

          // About
          if (summary != null) ...[
            _label('About'),
            Text(
              summary,
              maxLines: _fullSummary ? null : 4,
              overflow: _fullSummary
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: const TextStyle(
                color: UserUi.body,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
            if (summary.length > 220)
              _toggle(
                _fullSummary ? 'Show less' : 'Read more',
                () => setState(() => _fullSummary = !_fullSummary),
              ),
          ],

          // Skills
          if (p.skills.isNotEmpty) ...[
            _label('Skills · ${p.skills.length}'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in shownSkills) SkillChip(text: skill),
                if (hiddenSkills > 0)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _allSkills = true),
                    child: SkillChip(
                      text: '+$hiddenSkills more',
                      color: UserUi.muted,
                    ),
                  ),
              ],
            ),
            if (_allSkills && p.skills.length > _skillLimit)
              _toggle('Show fewer', () => setState(() => _allSkills = false)),
          ],

          // Experience
          if (p.work.isNotEmpty) ...[
            _label('Experience'),
            for (final job in shownWork)
              _entry(
                icon: Icons.business_center_outlined,
                color: UserUi.blue,
                title: job.title ?? job.company ?? 'Role',
                line1: job.title != null ? job.company : null,
                line2: job.duration,
              ),
            if (p.work.length > _workLimit)
              _toggle(
                _allWork ? 'Show less' : 'Show all ${p.work.length} roles',
                () => setState(() => _allWork = !_allWork),
              ),
          ],

          // Education
          if (p.education.isNotEmpty) ...[
            _label('Education'),
            for (final item in p.education)
              _entry(
                icon: Icons.school_outlined,
                color: UserUi.teal,
                title: item.title,
                line1: item.institution,
                line2: item.year,
              ),
          ],

          // Certifications
          if (p.certifications.isNotEmpty) ...[
            _label('Certifications'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cert in p.certifications)
                  SkillChip(
                    text: cert,
                    color: UserUi.amber,
                    icon: Icons.workspace_premium_outlined,
                  ),
              ],
            ),
          ],

          // Languages
          if (p.languages.isNotEmpty) ...[
            _label('Languages'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final language in p.languages)
                  SkillChip(text: language, color: UserUi.green),
              ],
            ),
          ],

          // Projects
          if (p.projects.isNotEmpty) ...[
            _label('Projects'),
            for (final project in p.projects.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6, color: UserUi.blue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        project,
                        style: const TextStyle(
                          color: UserUi.body,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w800,
          color: UserUi.faint,
        ),
      ),
    );
  }

  Widget _toggle(String text, VoidCallback onTap) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: UserUi.blue,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: UserUi.faint),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: UserUi.muted),
          ),
        ),
      ],
    );
  }

  Widget _entry({
    required IconData icon,
    required Color color,
    required String title,
    String? line1,
    String? line2,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: UserUi.navy,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                if (line1 != null)
                  Text(
                    line1,
                    style: const TextStyle(color: UserUi.muted, fontSize: 13),
                  ),
                if (line2 != null)
                  Text(
                    line2,
                    style: const TextStyle(color: UserUi.faint, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
