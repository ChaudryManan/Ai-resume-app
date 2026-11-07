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
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout_outlined),
          ),
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
                    final isWide = constraints.maxWidth > 800;

                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 40 : 20,
                        vertical: 28,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Welcome section.
                              Text(
                                'Welcome back, $userName!',
                                style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.navy,
                                ),
                              ),

                              const SizedBox(height: 8),

                              const Text(
                                'Find your next opportunity and take the next step in your career.',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppTheme.textMuted,
                                ),
                              ),

                              const SizedBox(height: 28),

                              // Resume upload and management section.
                              _resumeSection(),

                              const SizedBox(height: 28),

                              // Statistics cards.
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  _statCard(
                                    title: 'Available Jobs',
                                    value: activeJobs.length.toString(),
                                    icon: Icons.work_outline,
                                    color: AppTheme.primary,
                                  ),
                                  _statCard(
                                    title: 'My Applications',
                                    value: applications.length.toString(),
                                    icon: Icons.description_outlined,
                                    color: Colors.orange,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 35),

                              // Search section.
                              const Text(
                                'Explore Opportunities',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.navy,
                                ),
                              ),

                              const SizedBox(height: 8),

                              const Text(
                                'Discover jobs that match your skills and interests.',
                                style: TextStyle(color: AppTheme.textMuted),
                              ),

                              const SizedBox(height: 20),

                              TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  setState(() {
                                    searchQuery = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText:
                                      'Search by job title, department or location...',
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: AppTheme.primary,
                                  ),
                                  suffixIcon: searchQuery.isNotEmpty
                                      ? IconButton(
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

                              const SizedBox(height: 24),

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
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),

                              // Job list.
                              if (filteredJobs.isEmpty)
                                _emptyJobs()
                              else
                                ...filteredJobs.map((doc) {
                                  final job = doc.data();
                                  final jobId = doc.id;

                                  final hasApplied = appliedJobIds.contains(
                                    jobId,
                                  );

                                  return _jobCard(
                                    job: job,
                                    jobId: jobId,
                                    hasApplied: hasApplied,
                                  );
                                }),

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

  // Candidate resume section.
  Widget _resumeSection() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _resumeStream,
      builder: (context, snapshot) {
        final hasResume = snapshot.hasData && snapshot.data!.exists;

        final resumeData = hasResume ? snapshot.data!.data() : null;

        final fileName = resumeData?['fileName']?.toString() ?? '';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: AppTheme.primary,
                    size: 25,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'My Resume',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navy,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                const Text(
                  'Unable to load your resume information.',
                  style: TextStyle(color: Colors.red),
                )
              else if (hasResume) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fileName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(Icons.check_circle, color: Colors.green),
                  ],
                ),

                const SizedBox(height: 12),

                const Text(
                  'Your resume is uploaded. You can replace it whenever you need.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ] else
                const Text(
                  'You have not uploaded a resume yet. Upload your PDF to apply for jobs.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: snapshot.connectionState == ConnectionState.waiting
                      ? null
                      : _pickAndUploadResume,
                  icon: Icon(hasResume ? Icons.refresh : Icons.upload_file),
                  label: Text(hasResume ? 'Replace Resume' : 'Upload Resume'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Statistics card.
  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 25),
          ),

          const SizedBox(width: 14),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Job card.
  Widget _jobCard({
    required Map<String, dynamic> job,
    required String jobId,
    required bool hasApplied,
  }) {
    final title = job['title']?.toString() ?? 'Untitled Job';
    final department = job['department']?.toString() ?? '';
    final location = job['location']?.toString() ?? 'Not specified';
    final jobType = job['jobType']?.toString() ?? '';
    final salary = job['salary']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.work_outline,
                  color: AppTheme.primary,
                  size: 26,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      department,
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),

              if (hasApplied)
                _tag('Applied', Colors.green)
              else
                _tag('Active', AppTheme.primary),
            ],
          ),

          const SizedBox(height: 20),

          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _jobInfo(Icons.location_on_outlined, location),
              if (jobType.isNotEmpty) _jobInfo(Icons.access_time, jobType),
              if (salary.isNotEmpty) _jobInfo(Icons.payments_outlined, salary),
            ],
          ),

          const SizedBox(height: 20),

          const Divider(color: Color(0xFFE2E8F0)),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    _showJobDetails(
                      job: job,
                      jobId: jobId,
                      hasApplied: hasApplied,
                    );
                  },
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
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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

  // Job details bottom sheet.
  void _showJobDetails({
    required Map<String, dynamic> job,
    required String jobId,
    required bool hasApplied,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                Text(
                  job['title']?.toString() ?? 'Job Details',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  '${job['department'] ?? ''} • ${job['location'] ?? ''}',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),

                const SizedBox(height: 25),

                _detailSection(
                  'Job Description',
                  job['description']?.toString() ?? 'Not provided',
                ),

                _detailSection(
                  'Responsibilities',
                  job['responsibilities']?.toString() ?? 'Not provided',
                ),

                _detailSection('Required Skills', _formatSkills(job['skills'])),

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

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
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
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Text(
                      hasApplied ? 'Already Applied' : 'Apply for this Job',
                    ),
                  ),
                ),
              ],
            ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
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
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
