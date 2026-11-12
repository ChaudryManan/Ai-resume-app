import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/admin_service.dart';
import '../services/job_matching_service.dart';
import 'generate_offer_dialog.dart';

class CandidatesScreen extends StatefulWidget {
  const CandidatesScreen({super.key, this.requestedJobId});

  /// Set by the dashboard when the admin taps "View candidates" on a job.
  final ValueNotifier<String?>? requestedJobId;

  @override
  State<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _JobOption {
  const _JobOption(this.id, this.title, this.subtitle);

  final String id;
  final String title;
  final String subtitle; // department
}

const Color _navy = Color(0xFF172554);
const Color _blue = Color(0xFF4F6EF7);
const Color _green = Color(0xFF059669);
const Color _amber = Color(0xFFD97706);
const Color _red = Color(0xFFDC6262);
const Color _muted = Color(0xFF64748B);
const Color _faint = Color(0xFF94A3B8);
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

  // all | highly_eligible | potential | low_match
  String _filter = 'highly_eligible';

  @override
  void initState() {
    super.initState();

    _jobsSubscription = _adminService.getJobs().listen(
      (snapshot) {
        if (!mounted) return;

        final jobs = snapshot.docs.map((doc) {
          final title = (doc.data()['title'] ?? '').toString().trim();
          final department = (doc.data()['department'] ?? '').toString().trim();
          return _JobOption(
            doc.id,
            title.isEmpty ? 'Untitled job' : title,
            department,
          );
        }).toList();

        setState(() {
          _jobs = jobs;
          _jobsLoaded = true;
          _jobsError = null;
        });

        final requested = widget.requestedJobId?.value;
        if (requested != null && jobs.any((job) => job.id == requested)) {
          widget.requestedJobId?.value = null; // used once
          _selectJob(requested);
          return;
        }

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

  Future<void> _generateOffer(CandidateMatch candidate) async {
    final jobId = _selectedJobId;
    if (jobId == null) return;
    if (candidate.email == null || candidate.email!.trim().isEmpty) {
      _showMessage('This candidate resume does not contain an email address.', isError: true);
      return;
    }
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GenerateOfferDialog(
        candidateId: candidate.candidateId,
        candidateName: candidate.displayName,
        candidateEmail: candidate.email,
        jobId: jobId,
      ),
    );
    if (sent == true && mounted) {
      _showMessage('Job offer email sent successfully.');
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
      final inFilter =
          _filter == 'all' || candidate.eligibility == _filter;
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

  Future<void> _refresh() async {
    final jobId = _selectedJobId;
    if (jobId == null) return;
    await _load(jobId, silent: true);
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

  // Phone: the job is chosen from a bottom sheet instead of a small dropdown.
  Future<void> _showJobPicker() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 680),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  'Select a job',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: _jobs.length,
                  itemBuilder: (context, index) {
                    final job = _jobs[index];
                    final selected = job.id == _selectedJobId;

                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor:
                          selected ? _blue.withValues(alpha: 0.08) : null,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.work_outline,
                          color: _blue,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        job.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: job.subtitle.isEmpty
                          ? null
                          : Text(
                              job.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: selected
                          ? const Icon(Icons.check_circle, color: _blue)
                          : null,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        if (!selected) _selectJob(job.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _jobPickerCard() {
    final job = _jobs.firstWhere(
      (item) => item.id == _selectedJobId,
      orElse: () => _jobs.first,
    );

    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _showJobPicker,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.work_outline, color: _blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SELECTED JOB',
                      style: TextStyle(
                        color: _faint,
                        fontSize: 9.5,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.unfold_more_rounded, color: _muted),
            ],
          ),
        ),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      onPressed:
          (_selectedJobId == null || running) ? null : _runMatchingAgain,
      style: ElevatedButton.styleFrom(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              style: TextStyle(color: color, fontSize: 12.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A172554),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  Widget _jobPanel(bool isPhone) {
    if (isPhone) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(radius: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _jobPickerCard(),
            _statusLine(),
            const SizedBox(height: 14),
            _rerunButton(),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(radius: 15),
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
          Row(
            children: [
              Expanded(child: _jobDropdown()),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Reload results',
                onPressed: _selectedJobId == null || _loading
                    ? null
                    : () => _load(_selectedJobId!),
                icon: const Icon(Icons.sync, color: _muted),
              ),
              const SizedBox(width: 8),
              _rerunButton(),
            ],
          ),
          _statusLine(),
        ],
      ),
    );
  }

  // Tablet and desktop: four numbers.
  Widget _summaryCards(JobMatchData data) {
    final highly =
        data.results.where((c) => c.eligibility == 'highly_eligible').length;
    final potential =
        data.results.where((c) => c.eligibility == 'potential').length;
    final low = data.results.where((c) => c.eligibility == 'low_match').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 2;

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

  // Phone: the same four numbers, and tapping one filters the list.
  Widget _filterTiles(JobMatchData data) {
    int count(String eligibility) =>
        data.results.where((c) => c.eligibility == eligibility).length;

    Widget tile(String value, String label, int number, Color color) {
      final selected = _filter == value;

      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _filter = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.10) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? color : _border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '$number',
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: selected ? color : _muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tile('all', 'All\nmatched', data.results.length, _blue),
        const SizedBox(width: 8),
        tile('highly_eligible', 'Highly\neligible', count('highly_eligible'), _green),
        const SizedBox(width: 8),
        tile('potential', 'Potential\nfit', count('potential'), _amber),
        const SizedBox(width: 8),
        tile('low_match', 'Low\nmatch', count('low_match'), _red),
      ],
    );
  }

  Widget _filterDropdown() {
    return DropdownButtonFormField<String>(
      key: ValueKey(_filter),
      initialValue: _filter,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Show',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All matched')),
        DropdownMenuItem(
          value: 'highly_eligible',
          child: Text('Highly eligible'),
        ),
        DropdownMenuItem(value: 'potential', child: Text('Potential')),
        DropdownMenuItem(value: 'low_match', child: Text('Low match')),
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
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
      ),
    );
  }

  Widget _emptyState(
    IconData icon,
    String title, {
    String? hint,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: _blue),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _navy,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _faint, fontSize: 12.5, height: 1.4),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 10), action],
          ],
        ),
      ),
    );
  }

  Widget _candidateList(JobMatchData data) {
    final visible = _visibleCandidates(data);
    final searching = _searchController.text.trim().isNotEmpty;

    if (data.results.isEmpty) {
      return _emptyState(
        Icons.person_search_outlined,
        data.isRunning
            ? 'Looking for candidates...'
            : 'No matched candidates yet',
        hint: data.isRunning
            ? null
            : 'Candidates appear here after their resume is screened and the '
                'job is matched.',
      );
    }

    if (visible.isEmpty) {
      final highlyOnly = _filter == 'highly_eligible' && !searching;

      return _emptyState(
        searching ? Icons.search_off : Icons.person_search_outlined,
        searching
            ? 'No candidates match your search'
            : _filter == 'highly_eligible'
                ? 'No highly eligible candidates yet'
                : _filter == 'potential'
                    ? 'No potential candidates'
                    : _filter == 'low_match'
                        ? 'No low-match candidates'
                        : 'No candidates here',
        hint: highlyOnly
            ? 'Highly eligible means a score of 75 or more with no knock-out.'
            : null,
        action: highlyOnly
            ? TextButton(
                onPressed: () => setState(() => _filter = 'potential'),
                child: const Text('Show potential candidates'),
              )
            : null,
      );
    }

    return Column(
      children: visible
          .map(
            (candidate) => _CandidateCard(
              key: ValueKey(candidate.candidateId),
              candidate: candidate,
              onOpenResume: () => _openResume(candidate),
              onGenerateOffer: () => _generateOffer(candidate),
            ),
          )
          .toList(),
    );
  }

  Widget _resultsPanel(JobMatchData data, bool isPhone) {
    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _searchField(),
          const SizedBox(height: 14),
          _candidateList(data),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(radius: 15),
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
          Row(
            children: [
              Expanded(child: _searchField()),
              const SizedBox(width: 14),
              SizedBox(width: 230, child: _filterDropdown()),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: _border),
          const SizedBox(height: 8),
          _candidateList(data),
        ],
      ),
    );
  }

  Widget _content(bool isPhone) {
    if (!_jobsLoaded) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_jobsError != null) {
      return _emptyState(
        Icons.cloud_off_rounded,
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
    final gap = isPhone ? 16.0 : 22.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _jobPanel(isPhone),
        SizedBox(height: gap),
        if (_loadError != null)
          _emptyState(
            Icons.cloud_off_rounded,
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
          if (isPhone) _filterTiles(data) else _summaryCards(data),
          SizedBox(height: gap),
          _resultsPanel(data, isPhone),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FC),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 600;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.all(isPhone ? 16 : 24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isPhone) ...[
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
                      ],
                      _content(isPhone),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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
    required this.onGenerateOffer,
  });

  final CandidateMatch candidate;
  final Future<void> Function() onOpenResume;
  final Future<void> Function() onGenerateOffer;

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

  Widget _tag(String text, Color color) {
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

  // The score as a ring: readable at a glance, and compact for phones.
  Widget _scoreRing(Color color) {
    final fraction = (_candidate.score / 100).clamp(0.0, 1.0).toDouble();

    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            _candidate.score.toStringAsFixed(0),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moreChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
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
            fontWeight: FontWeight.w700,
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
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
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
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            children: [
              SizedBox(
                width: 112,
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
                width: 36,
                child: Text(
                  value.toStringAsFixed(0),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

    // Collapsed cards show a few skills; details show every one.
    final matched = _expanded
        ? candidate.matchedSkills
        : candidate.matchedSkills.take(4).toList();
    final missing = _expanded
        ? candidate.missingSkills
        : candidate.missingSkills.take(3).toList();
    final hidden = (candidate.matchedSkills.length - matched.length) +
        (candidate.missingSkills.length - missing.length);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFFEEF2FF),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _tag(_eligibilityLabel(candidate.eligibility), color),
                        _tag('Rank #${candidate.rank}', _blue),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _scoreRing(color),
            ],
          ),
          if (matched.isNotEmpty || missing.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in matched)
                  _skillChip(skill, _green, Icons.check),
                for (final skill in missing)
                  _skillChip(skill, _red, Icons.close),
                if (hidden > 0) _moreChip('+$hidden more'),
              ],
            ),
          ],
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
                style: const TextStyle(color: _navy, fontSize: 13, height: 1.45),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _opening ? null : _openResume,
                  icon: _opening
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.description_outlined, size: 18),
                  label: const Text('View resume'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: BorderSide(color: _blue.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(_expanded ? 'Hide details' : 'Show details'),
                  style: TextButton.styleFrom(
                    foregroundColor: _navy,
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: candidate.email == null ? null : widget.onGenerateOffer,
              icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
              label: const Text('Generate job offer'),
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 14),
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
