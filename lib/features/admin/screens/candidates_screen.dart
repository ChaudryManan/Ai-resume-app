import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/admin_service.dart';
import '../services/job_matching_service.dart';

class CandidatesScreen extends StatefulWidget {
  const CandidatesScreen({super.key});

  @override
  State<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _JobOption {
  const _JobOption(this.id, this.title);

  final String id;
  final String title;
}

const Color _navy = Color(0xFF172554);
const Color _blue = Color(0xFF4F6EF7);
const Color _green = Color(0xFF059669);
const Color _amber = Color(0xFFD97706);
const Color _red = Color(0xFFDC6262);
const Color _muted = Color(0xFF64748B);
const Color _border = Color(0xFFE9EDF5);

Color _eligibilityColor(String eligibility) {
  switch (eligibility) {
    case 'highly_eligible':
      return _green;
    case 'potential':
      return _amber;
    default:
      return _red;
  }
}

String _eligibilityLabel(String eligibility) {
  switch (eligibility) {
    case 'highly_eligible':
      return 'Highly eligible';
    case 'potential':
      return 'Potential';
    default:
      return 'Low match';
  }
}

String _friendlyError(Object error) {
  return error.toString().replaceFirst('Bad state: ', '');
}

String _timeAgo(DateTime time) {
  final difference = DateTime.now().difference(time.toLocal());

  if (difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  return '${difference.inDays} d ago';
}

class _CandidatesScreenState extends State<CandidatesScreen> {
  static const int _maxPollAttempts = 100; // 100 x 3 seconds = 5 minutes

  final AdminService _adminService = AdminService();
  final JobMatchingService _matchingService = JobMatchingService();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _jobsSubscription;
  Timer? _poller;
  int _pollAttempts = 0;

  List<_JobOption> _jobs = [];
  bool _jobsLoaded = false;
  String? _jobsError;
  String? _selectedJobId;

  JobMatchData? _data;
  String? _loadError;
  bool _loading = false;
  bool _starting = false;

  // highly_eligible | eligible (highly eligible + potential) | all
  String _filter = 'highly_eligible';

  @override
  void initState() {
    super.initState();

    _jobsSubscription = _adminService.getJobs().listen(
      (snapshot) {
        if (!mounted) return;

        final jobs = snapshot.docs.map((doc) {
          final title = (doc.data()['title'] ?? '').toString().trim();
          return _JobOption(doc.id, title.isEmpty ? 'Untitled job' : title);
        }).toList();

        setState(() {
          _jobs = jobs;
          _jobsLoaded = true;
          _jobsError = null;
        });

        final stillExists = jobs.any((job) => job.id == _selectedJobId);
        if (!stillExists && jobs.isNotEmpty) {
          _selectJob(jobs.first.id);
        } else if (!stillExists) {
          setState(() {
            _selectedJobId = null;
            _data = null;
          });
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _jobsError = _friendlyError(error);
          _jobsLoaded = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _jobsSubscription?.cancel();
    _stopPolling();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- data

  Future<void> _selectJob(String jobId) async {
    _stopPolling();

    setState(() {
      _selectedJobId = jobId;
      _data = null;
      _loadError = null;
    });

    await _load(jobId);
  }

  Future<void> _load(String jobId, {bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }

    try {
      final data = await _matchingService.fetchMatches(jobId);
      if (!mounted || _selectedJobId != jobId) return;

      setState(() {
        _data = data;
        _loadError = null;
        _loading = false;
      });

      if (data.isRunning) {
        _startPolling(jobId);
      } else {
        _stopPolling();
      }
    } catch (error) {
      if (!mounted || _selectedJobId != jobId) return;

      setState(() {
        _loading = false;
        if (!silent) {
          _loadError = _friendlyError(error);
        }
      });
    }
  }

  void _startPolling(String jobId) {
    if (_poller != null) return;

    _pollAttempts = 0;
    _poller = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollAttempts++;

      if (_pollAttempts > _maxPollAttempts) {
        _stopPolling();
        return;
      }

      _load(jobId, silent: true);
    });
  }

  void _stopPolling() {
    _poller?.cancel();
    _poller = null;
  }

  Future<void> _runMatchingAgain() async {
    final jobId = _selectedJobId;
    if (jobId == null || _starting) return;

    setState(() => _starting = true);

    try {
      await _matchingService.startMatching(jobId);
      if (!mounted) return;

      _showMessage('Matching started. The list updates when it finishes.');

      _stopPolling();
      await _load(jobId, silent: true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  Future<void> _openResume(CandidateMatch candidate) async {
    try {
      final link = await _matchingService.getResumeLink(candidate.candidateId);
      final opened = await launchUrl(
        Uri.parse(link.url),
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _showLinkDialog(link);
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  void _showLinkDialog(ResumeLink link) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(link.fileName ?? 'Resume'),
          content: SelectableText(
            'Your browser blocked the new tab. Copy this link (valid for '
            '10 minutes):\n\n${link.url}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  List<CandidateMatch> _visibleCandidates(JobMatchData data) {
    final query = _searchController.text.trim().toLowerCase();

    return data.results.where((candidate) {
      final inFilter = switch (_filter) {
        'highly_eligible' => candidate.eligibility == 'highly_eligible',
        'eligible' => candidate.eligibility != 'low_match',
        _ => true,
      };
      if (!inFilter) return false;
      if (query.isEmpty) return true;

      final haystack = [
        candidate.displayName,
        candidate.email ?? '',
        candidate.title ?? '',
        ...candidate.matchedSkills,
        ...candidate.missingSkills,
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  // ------------------------------------------------------------------ UI

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobDropdown() {
    return DropdownButtonFormField<String>(
      // A new key rebuilds the field when the selected job changes.
      key: ValueKey(_selectedJobId),
      initialValue: _selectedJobId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Job',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: _jobs
          .map(
            (job) => DropdownMenuItem<String>(
              value: job.id,
              child: Text(job.title, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null && value != _selectedJobId) {
          _selectJob(value);
        }
      },
    );
  }

  Widget _rerunButton() {
    final running = _starting || (_data?.isRunning ?? false);

    return ElevatedButton.icon(
      onPressed: (_selectedJobId == null || running)
          ? null
          : _runMatchingAgain,
      style: ElevatedButton.styleFrom(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: running
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.refresh, size: 18),
      label: Text(running ? 'Matching...' : 'Find candidates again'),
    );
  }

  Widget _statusLine() {
    final data = _data;

    if (data == null) {
      return const SizedBox.shrink();
    }

    IconData icon;
    Color color;
    String text;

    if (data.isRunning) {
      icon = Icons.hourglass_top;
      color = _amber;
      text = 'Matching is in progress. This usually takes under a minute.';
    } else if (data.status == 'failed') {
      icon = Icons.error_outline;
      color = _red;
      text = 'The last matching run failed'
          '${data.error == null ? '.' : ': ${data.error}'}';
    } else if (data.status == 'completed') {
      icon = Icons.check_circle_outline;
      color = _green;
      final when = data.matchedAt == null
          ? ''
          : 'Last matched ${_timeAgo(data.matchedAt!)}. ';
      final skipped = (data.skippedNoProfile ?? 0) > 0
          ? ' ${data.skippedNoProfile} candidate(s) skipped: resume not '
              'screened yet.'
          : '';
      text = '$when${data.evaluated ?? data.results.length} resumes '
          'evaluated.$skipped';
    } else {
      icon = Icons.info_outline;
      color = _muted;
      text = 'This job has not been matched yet. Press "Find candidates '
          'again" to start.';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select a job',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final refresh = IconButton(
                tooltip: 'Reload results',
                onPressed: _selectedJobId == null || _loading
                    ? null
                    : () => _load(_selectedJobId!),
                icon: const Icon(Icons.sync, color: _muted),
              );

              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _jobDropdown(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _rerunButton()),
                        const SizedBox(width: 6),
                        refresh,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: _jobDropdown()),
                  const SizedBox(width: 6),
                  refresh,
                  const SizedBox(width: 8),
                  _rerunButton(),
                ],
              );
            },
          ),
          _statusLine(),
        ],
      ),
    );
  }

  Widget _summaryCards(JobMatchData data) {
    final highly =
        data.results.where((c) => c.eligibility == 'highly_eligible').length;
    final potential =
        data.results.where((c) => c.eligibility == 'potential').length;
    final low = data.results.where((c) => c.eligibility == 'low_match').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700
            ? 4
            : constraints.maxWidth >= 450
                ? 2
                : 1;

        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: width,
              child: _summaryCard(
                'Resumes Evaluated',
                '${data.results.length}',
                Icons.people_outline,
                _blue,
              ),
            ),
            SizedBox(
              width: width,
              child: _summaryCard(
                'Highly Eligible',
                '$highly',
                Icons.verified_outlined,
                _green,
              ),
            ),
            SizedBox(
              width: width,
              child: _summaryCard(
                'Potential',
                '$potential',
                Icons.trending_up,
                _amber,
              ),
            ),
            SizedBox(
              width: width,
              child: _summaryCard(
                'Low Match',
                '$low',
                Icons.remove_circle_outline,
                _red,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterDropdown() {
    return DropdownButtonFormField<String>(
      key: ValueKey(_filter),
      initialValue: _filter,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Show',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: const [
        DropdownMenuItem(
          value: 'highly_eligible',
          child: Text('Highly eligible'),
        ),
        DropdownMenuItem(
          value: 'eligible',
          child: Text('Highly eligible + potential'),
        ),
        DropdownMenuItem(value: 'all', child: Text('All matched')),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _filter = value);
        }
      },
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search by name, email or skill...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, {String? hint, Widget? action}) {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 45, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 10), action],
          ],
        ),
      ),
    );
  }

  Widget _resultsPanel(JobMatchData data) {
    final visible = _visibleCandidates(data);

    Widget body;
    if (data.results.isEmpty) {
      body = _emptyState(
        Icons.person_search_outlined,
        data.isRunning ? 'Looking for candidates...' : 'No matched candidates yet',
        hint: data.isRunning
            ? null
            : 'Candidates appear here after their resume is screened and the '
                'job is matched.',
      );
    } else if (visible.isEmpty) {
      body = _emptyState(
        Icons.search_off,
        _filter == 'highly_eligible'
            ? 'No highly eligible candidates for this job yet'
            : 'No candidates match your search',
        hint: 'Highly eligible means a score of 75 or more with no knock-out.',
        action: _filter == 'highly_eligible'
            ? TextButton(
                onPressed: () => setState(() => _filter = 'eligible'),
                child: const Text('Also show potential candidates'),
              )
            : null,
      );
    } else {
      body = Column(
        children: visible
            .map(
              (candidate) => _CandidateCard(
                key: ValueKey(candidate.candidateId),
                candidate: candidate,
                onOpenResume: () => _openResume(candidate),
              ),
            )
            .toList(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ranked Candidates',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    _searchField(),
                    const SizedBox(height: 12),
                    _filterDropdown(),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: _searchField()),
                  const SizedBox(width: 14),
                  SizedBox(width: 230, child: _filterDropdown()),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Divider(color: _border),
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }

  Widget _content() {
    if (!_jobsLoaded) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_jobsError != null) {
      return _emptyState(
        Icons.error_outline,
        'Could not load jobs',
        hint: _jobsError,
      );
    }

    if (_jobs.isEmpty) {
      return _emptyState(
        Icons.work_outline,
        'No jobs yet',
        hint: 'Create a job first. Candidates are matched to it automatically.',
      );
    }

    final data = _data;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _jobPanel(),
        const SizedBox(height: 22),
        if (_loadError != null)
          _emptyState(
            Icons.error_outline,
            'Could not load the results',
            hint: _loadError,
            action: TextButton(
              onPressed: _selectedJobId == null
                  ? null
                  : () => _load(_selectedJobId!),
              child: const Text('Try again'),
            ),
          )
        else if (data == null || _loading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _summaryCards(data),
          const SizedBox(height: 22),
          _resultsPanel(data),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Candidates',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'The best matching candidates for each job, ranked by AI.',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 24),
            _content(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One ranked candidate
// ---------------------------------------------------------------------------

class _CandidateCard extends StatefulWidget {
  const _CandidateCard({
    super.key,
    required this.candidate,
    required this.onOpenResume,
  });

  final CandidateMatch candidate;
  final Future<void> Function() onOpenResume;

  @override
  State<_CandidateCard> createState() => _CandidateCardState();
}

class _CandidateCardState extends State<_CandidateCard> {
  static const Map<String, String> _breakdownLabels = {
    'skills': 'Skills',
    'experience': 'Experience',
    'title': 'Role fit',
    'education': 'Education',
    'impact': 'Impact & growth',
    'semantic': 'Resume similarity',
  };

  bool _expanded = false;
  bool _opening = false;

  CandidateMatch get _candidate => widget.candidate;

  String get _initials {
    final parts = _candidate.displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  Future<void> _openResume() async {
    setState(() => _opening = true);
    try {
      await widget.onOpenResume();
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  Widget _skillChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: _navy,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _bullets(String title, List<String> items, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Icon(Icons.circle, size: 5, color: color),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(color: _navy, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _breakdown() {
    final rows = <Widget>[];

    _breakdownLabels.forEach((key, label) {
      final value = _candidate.breakdown[key];
      if (value == null) return;

      final fraction = (value / 100).clamp(0.0, 1.0).toDouble();

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFEEF2FF),
                    color: _eligibilityColor(
                      value >= 75
                          ? 'highly_eligible'
                          : value >= 60
                              ? 'potential'
                              : 'low_match',
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  value.toStringAsFixed(0),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });

    return Column(children: rows);
  }

  @override
  Widget build(BuildContext context) {
    final candidate = _candidate;
    final color = _eligibilityColor(candidate.eligibility);

    final subtitle = [
      if (candidate.title != null) candidate.title!,
      if (candidate.email != null) candidate.email!,
    ].join('  •  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${candidate.rank}',
                  style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFEEF2FF),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    candidate.score.toStringAsFixed(0),
                    style: TextStyle(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _eligibilityLabel(candidate.eligibility),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (candidate.matchedSkills.isNotEmpty ||
              candidate.missingSkills.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in candidate.matchedSkills)
                  _skillChip(skill, _green, Icons.check),
                for (final skill in candidate.missingSkills)
                  _skillChip(skill, _red, Icons.close),
              ],
            ),
          if (candidate.knockedOut && candidate.knockoutReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber, size: 16, color: _red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      candidate.knockoutReason!,
                      style: const TextStyle(color: _red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (candidate.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                candidate.summary,
                maxLines: _expanded ? null : 3,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: const TextStyle(color: _navy, fontSize: 13, height: 1.4),
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 28,
            runSpacing: 10,
            children: [
              _metric(
                'Relevant experience',
                '${candidate.relevantYears.toStringAsFixed(1)} of '
                    '${candidate.totalYears.toStringAsFixed(1)} yrs',
              ),
              _metric(
                'Must-have skills',
                '${(candidate.mustHaveCoverage * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _opening ? null : _openResume,
                icon: _opening
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.description_outlined, size: 18),
                label: const Text('View resume'),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(_expanded ? 'Hide details' : 'Show details'),
              ),
            ],
          ),
          if (_expanded) ...[
            const Divider(color: _border),
            const SizedBox(height: 8),
            _breakdown(),
            _bullets('Strengths', candidate.strengths, _green),
            _bullets('Gaps', candidate.gaps, _amber),
            _bullets('Red flags', candidate.redFlags, _red),
          ],
        ],
      ),
    );
  }
}
