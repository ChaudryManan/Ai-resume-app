import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../services/resume_processing_service.dart';
import '../services/user_job_service.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final UserJobService _jobService = UserJobService();

  final TextEditingController _searchController = TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _jobsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _applicationsStream;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _resumeStream;

  String searchQuery = '';

  // True while the resume is uploading / being analysed.
  bool _uploading = false;

  @override
  void initState() {
    super.initState();

    _jobsStream = _jobService.getJobs();
    _applicationsStream = _jobService.getMyApplications();
    _resumeStream = _jobService.getMyResume();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get userName {
    final name = FirebaseAuth.instance.currentUser?.displayName;

    if (name == null || name.trim().isEmpty) {
      return 'Candidate';
    }

    return name;
  }

  // Upload or replace the candidate's resume.
  Future<void> _pickAndUploadResume() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (file == null || !mounted) return;

      final fileSize = await file.length();

      if (!mounted) return;

      if (fileSize == null || fileSize > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Resume must not exceed 5 MB or file size could not be read.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      if (bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The selected file is empty.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _uploading = true);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uploading your resume...')));

      await _jobService.uploadOrReplaceResume(
        resumeBytes: bytes,
        resumeFileName: file.name,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resume uploaded. Analysing it with AI, this can take up to a minute...'),
        ),
      );

      try {
        final chunksStored = await ResumeProcessingService()
            .processResume();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Resume uploaded and indexed in $chunksStored sections.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (processingError) {
        debugPrint('RESUME PROCESSING ERROR: $processingError');

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Resume uploaded, but processing failed: $processingError',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('RESUME UPLOAD ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Resume upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // Apply for a job using the already-uploaded resume.
  Future<void> applyForJob(String jobId, String jobTitle) async {
    try {
      await _jobService.applyForJob(jobId: jobId, jobTitle: jobTitle);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('APPLICATION ERROR: $e');

      if (!mounted) return;

      String message;

      if (e.toString().contains('already applied')) {
        message = 'You have already applied for this job.';
      } else if (e.toString().contains('upload your resume')) {
        message = 'Please upload your resume before applying.';
      } else {
        message = 'Application failed: $e';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }


  // Same confirmation the admin side uses, so one tap can't sign you out.
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Log out?'),
          content: const Text('You will need to sign in again to apply for jobs.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC6262),
              ),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  // ----------------------------------------------------------------- build

  static const Color _border = Color(0xFFE2E8F0);
  static const List<BoxShadow> _softShadow = [
    BoxShadow(color: Color(0x0A172554), blurRadius: 14, offset: Offset(0, 4)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.work_outline, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            const Text(
              'HireFlow',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.navy,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _jobsStream,
          builder: (context, jobSnapshot) {
            if (jobSnapshot.hasError) {
              return const Center(child: Text('Unable to load jobs.'));
            }

            if (jobSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }

            final allJobs = jobSnapshot.data?.docs ?? [];

            // Only show active jobs to candidates.
            final activeJobs = allJobs.where((doc) {
              final data = doc.data();

              return (data['status'] ?? 'Active') == 'Active';
            }).toList();

            // Search jobs.
            final filteredJobs = activeJobs.where((doc) {
              final data = doc.data();

              final title = (data['title'] ?? '').toString().toLowerCase();

              final department = (data['department'] ?? '')
                  .toString()
                  .toLowerCase();

              final location = (data['location'] ?? '')
                  .toString()
                  .toLowerCase();

              final query = searchQuery.toLowerCase();

              return title.contains(query) ||
                  department.contains(query) ||
                  location.contains(query);
            }).toList();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _applicationsStream,
              builder: (context, applicationSnapshot) {
                if (applicationSnapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load applications.'),
                  );
                }

                if (applicationSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }

                final applications = applicationSnapshot.data?.docs ?? [];

                final appliedJobIds = applications
                    .map((doc) => doc.data()['jobId'].toString())
                    .toSet();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 600;
                    final isWide = constraints.maxWidth > 800;
                    final padding = compact ? 16.0 : (isWide ? 40.0 : 24.0);
                    final contentWidth = (constraints.maxWidth - padding * 2)
                        .clamp(0.0, 1200.0)
                        .toDouble();

                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.symmetric(
                        horizontal: padding,
                        vertical: compact ? 18 : 28,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Welcome section.
                              _welcomeCard(compact),

                              SizedBox(height: compact ? 16 : 24),

                              // Resume upload and management section.
                              _resumeSection(compact),

                              SizedBox(height: compact ? 16 : 24),

                              // Statistics cards.
                              _statRow(
                                contentWidth: contentWidth,
                                compact: compact,
                                cards: (width) => [
                                  SizedBox(
                                    width: width,
                                    child: _statCard(
                                      title: 'Available Jobs',
                                      value: activeJobs.length.toString(),
                                      icon: Icons.work_outline,
                                      color: AppTheme.primary,
                                      compact: compact,
                                    ),
                                  ),
                                  SizedBox(
                                    width: width,
                                    child: _statCard(
                                      title: 'My Applications',
                                      value: applications.length.toString(),
                                      icon: Icons.description_outlined,
                                      color: Colors.orange,
                                      compact: compact,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: compact ? 28 : 35),

                              // Search section.
                              Text(
                                'Explore Opportunities',
                                style: TextStyle(
                                  fontSize: compact ? 20 : 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.navy,
                                ),
                              ),

                              const SizedBox(height: 6),

                              const Text(
                                'Discover jobs that match your skills and interests.',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: 16),

                              TextField(
                                controller: _searchController,
                                textInputAction: TextInputAction.search,
                                onChanged: (value) {
                                  setState(() {
                                    searchQuery = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: compact
                                      ? 'Search title, department, location'
                                      : 'Search by job title, department or location...',
                                  hintMaxLines: 1,
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: AppTheme.primary,
                                  ),
                                  suffixIcon: searchQuery.isNotEmpty
                                      ? IconButton(
                                          tooltip: 'Clear search',
                                          onPressed: () {
                                            _searchController.clear();

                                            setState(() {
                                              searchQuery = '';
                                            });
                                          },
                                          icon: const Icon(Icons.close),
                                        )
                                      : null,
                                ),
                              ),

                              const SizedBox(height: 22),

                              // Jobs heading.
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Latest Jobs',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.navy,
                                    ),
                                  ),
                                  Text(
                                    '${filteredJobs.length} jobs found',
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Job list: one column on phones and tablets,
                              // two on wide screens.
                              if (filteredJobs.isEmpty)
                                _emptyJobs()
                              else
                                _jobGrid(
                                  contentWidth: contentWidth,
                                  compact: compact,
                                  jobs: filteredJobs,
                                  appliedJobIds: appliedJobIds,
                                ),

                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // --------------------------------------------------------------- widgets

  Widget _welcomeCard(bool compact) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(compact ? 20 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.navy, Color(0xFF1E3A8A)],
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, $userName!',
                style: TextStyle(
                  fontSize: compact ? 22 : 27,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Find your next opportunity and take the next step in your career.',
                style: TextStyle(
                  fontSize: compact ? 13.5 : 15,
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Candidate resume section.
  Widget _resumeSection(bool compact) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _resumeStream,
      builder: (context, snapshot) {
        final hasResume = snapshot.hasData && snapshot.data!.exists;

        final resumeData = hasResume ? snapshot.data!.data() : null;

        final fileName = resumeData?['fileName']?.toString() ?? '';

        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: _softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'My Resume',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              if (loading)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                const Text(
                  'Unable to load your resume information.',
                  style: TextStyle(color: Colors.red),
                )
              else if (hasResume) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf,
                        color: Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Your resume is uploaded. You can replace it whenever you need.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                    height: 1.4,
                  ),
                ),
              ] else
                const Text(
                  'You have not uploaded a resume yet. Upload your PDF to apply for jobs.',
                  style: TextStyle(color: AppTheme.textMuted, height: 1.4),
                ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (loading || _uploading)
                      ? null
                      : _pickAndUploadResume,
                  icon: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        )
                      : Icon(hasResume ? Icons.refresh : Icons.upload_file),
                  label: Text(
                    _uploading
                        ? 'Uploading & analysing...'
                        : (hasResume ? 'Replace Resume' : 'Upload Resume'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppTheme.primary.withValues(alpha: 0.12),
                    disabledForegroundColor: AppTheme.primary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  /// Two cards: side by side filling the row on phones, fixed width otherwise.
  Widget _statRow({
    required double contentWidth,
    required bool compact,
    required List<Widget> Function(double width) cards,
  }) {
    const gap = 12.0;
    final width = compact ? (contentWidth - gap) / 2 : 230.0;

    return Wrap(spacing: gap, runSpacing: gap, children: cards(width));
  }

  // Statistics card.
  Widget _statCard({
    required String title,
    required String value,
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
        boxShadow: _softShadow,
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
          SizedBox(height: compact ? 12 : 14),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 26 : 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobGrid({
    required double contentWidth,
    required bool compact,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs,
    required Set<String> appliedJobIds,
  }) {
    const gap = 14.0;
    final twoColumns = contentWidth >= 900;
    final width = twoColumns ? (contentWidth - gap) / 2 : contentWidth;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: jobs.map((doc) {
        return SizedBox(
          width: width,
          child: _jobCard(
            job: doc.data(),
            jobId: doc.id,
            hasApplied: appliedJobIds.contains(doc.id),
            compact: compact,
          ),
        );
      }).toList(),
    );
  }

  // Job card.
  Widget _jobCard({
    required Map<String, dynamic> job,
    required String jobId,
    required bool hasApplied,
    required bool compact,
  }) {
    final title = job['title']?.toString() ?? 'Untitled Job';
    final department = job['department']?.toString() ?? '';
    final location = job['location']?.toString() ?? 'Not specified';
    final jobType = job['jobType']?.toString() ?? '';
    final salary = job['salary']?.toString() ?? '';

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.work_outline,
                  color: AppTheme.primary,
                  size: 24,
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
                        fontSize: compact ? 17 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                        height: 1.25,
                      ),
                    ),
                    if (department.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        department,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              if (hasApplied)
                _tag('Applied', Colors.green)
              else
                _tag('Active', AppTheme.primary),
            ],
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _jobInfo(Icons.location_on_outlined, location),
              if (jobType.isNotEmpty) _jobInfo(Icons.access_time, jobType),
              if (salary.isNotEmpty) _jobInfo(Icons.payments_outlined, salary),
            ],
          ),

          const SizedBox(height: 16),

          const Divider(height: 1, color: _border),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _showJobDetails(
                      job: job,
                      jobId: jobId,
                      hasApplied: hasApplied,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('View Details'),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ElevatedButton(
                  onPressed: hasApplied
                      ? null
                      : () => applyForJob(jobId, title),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.green.shade50,
                    disabledForegroundColor: Colors.green,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(hasApplied ? 'Applied' : 'Apply Now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Job details bottom sheet. The Apply button stays pinned at the bottom,
  // so on a phone you don't have to scroll to the end to apply.
  void _showJobDetails({
    required Map<String, dynamic> job,
    required String jobId,
    required bool hasApplied,
  }) {
    showModalBottomSheet(
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
                        job['title']?.toString() ?? 'Job Details',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navy,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        '${job['department'] ?? ''} • ${job['location'] ?? ''}',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),

                      const SizedBox(height: 24),

                      _detailSection(
                        'Job Description',
                        job['description']?.toString() ?? 'Not provided',
                      ),

                      _detailSection(
                        'Responsibilities',
                        job['responsibilities']?.toString() ?? 'Not provided',
                      ),

                      _detailSection(
                        'Required Skills',
                        _formatSkills(job['skills']),
                      ),

                      _detailSection(
                        'Education',
                        job['education']?.toString() ?? 'Not specified',
                      ),

                      _detailSection(
                        'Experience',
                        job['experience']?.toString() ?? 'Not specified',
                      ),

                      _detailSection(
                        'Salary',
                        job['salary']?.toString() ?? 'Not specified',
                      ),
                    ],
                  ),
                ),
              ),

              // Pinned apply bar.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: _border)),
                ),
                child: SafeArea(
                  top: false,
                  child: ElevatedButton(
                    onPressed: hasApplied
                        ? null
                        : () {
                            Navigator.pop(sheetContext);

                            applyForJob(
                              jobId,
                              job['title']?.toString() ?? 'Job',
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      hasApplied ? 'Already Applied' : 'Apply for this Job',
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

  Widget _detailSection(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(height: 1.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  String _formatSkills(dynamic skills) {
    if (skills is List) {
      return skills.join(', ');
    }

    if (skills == null || skills.toString().isEmpty) {
      return 'Not specified';
    }

    return skills.toString();
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
          Icon(icon, size: 15, color: AppTheme.textMuted),
          const SizedBox(width: 5),
          // Flexible so a long location wraps instead of overflowing.
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _emptyJobs() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          Icon(Icons.work_off_outlined, size: 45, color: AppTheme.textMuted),
          SizedBox(height: 15),
          Text(
            'No jobs found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.navy,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'There are currently no active jobs matching your search.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
