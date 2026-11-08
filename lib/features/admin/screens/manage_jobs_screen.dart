import 'package:cloud_firestore/cloud_firestore.dart';
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

const RoundedRectangleBorder _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
);

// ------------------------------------------------------------------ helpers

// Older jobs have no status field: they count as Active everywhere.
String _statusOf(Map<String, dynamic> job) =>
    (job['status'] ?? 'Active').toString();

String _text(Object? value, [String fallback = 'Not specified']) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}

DateTime? _dateOf(Object? value) => value is Timestamp ? value.toDate() : null;

List<String> _skillsOf(Map<String, dynamic> job) {
  final skills = job['skills'];
  if (skills is! List) return <String>[];

  return skills
      .map((skill) => skill.toString().trim())
      .where((skill) => skill.isNotEmpty)
      .toList();
}

String _timeAgo(DateTime time) {
  final difference = DateTime.now().difference(time.toLocal());

  if (difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  if (difference.inDays < 30) return '${difference.inDays} d ago';
  return '${(difference.inDays / 30).floor()} mo ago';
}

class _MatchInfo {
  const _MatchInfo(this.label, this.color);

  final String label;
  final Color color;
}

_MatchInfo? _matchInfo(Map<String, dynamic> job) {
  switch (job['matchStatus']) {
    case 'processing':
      return const _MatchInfo('Matching...', _amber);
    case 'failed':
      return const _MatchInfo('Match failed', _red);
    case 'completed':
      {
        final evaluated = job['matchEvaluated'];
        if (evaluated is num) {
          return _MatchInfo('${evaluated.toInt()} resumes matched', _blue);
        }
        return const _MatchInfo('Matched', _blue);
      }
  }
  return null;
}

Widget _chip(String text, Color color, {double fontSize = 11}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget _skillChip(String skill) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      skill,
      style: const TextStyle(
        color: Color(0xFF475569),
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget _statusBadge(String status) {
  return _chip(status, status == 'Active' ? _green : _red);
}

// ------------------------------------------------------------------- screen

class ManageJobsScreen extends StatefulWidget {
  const ManageJobsScreen({super.key, this.onViewCandidates, this.onCreateJob});

  /// Opens the Candidates page with this job selected.
  final ValueChanged<String>? onViewCandidates;

  /// Opens the Create Job page.
  final VoidCallback? onCreateJob;

  @override
  State<ManageJobsScreen> createState() => _ManageJobsScreenState();
}

class _ManageJobsScreenState extends State<ManageJobsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AdminService _adminService = AdminService();

  // Created once, so redrawing the dashboard does not restart the stream.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _jobsStream =
      _adminService.getJobs();

  String selectedFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Search and filter the real Firestore jobs.
  List<Map<String, dynamic>> getFilteredJobs(List<Map<String, dynamic>> jobs) {
    final query = _searchController.text.trim().toLowerCase();

    return jobs.where((job) {
      final haystack = [
        _text(job['title'], ''),
        _text(job['department'], ''),
        _text(job['location'], ''),
        ..._skillsOf(job),
      ].join(' ').toLowerCase();

      final matchesSearch = query.isEmpty || haystack.contains(query);
      final matchesFilter =
          selectedFilter == 'All' || _statusOf(job) == selectedFilter;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _message(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  // ----------------------------------------------------------- job actions

  Future<void> _showJobDetails(Map<String, dynamic> job) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 680),
      shape: _sheetShape,
      builder: (sheetContext) {
        return _JobDetailsSheet(
          job: job,
          onEdit: () {
            Navigator.pop(sheetContext);
            _editJob(job);
          },
          onToggleStatus: () {
            Navigator.pop(sheetContext);
            _toggleJobStatus(job);
          },
          onViewCandidates: widget.onViewCandidates == null
              ? null
              : () {
                  Navigator.pop(sheetContext);
                  widget.onViewCandidates!(job['id'] as String);
                },
        );
      },
    );
  }

  Future<void> _editJob(Map<String, dynamic> job) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 680),
      shape: _sheetShape,
      builder: (sheetContext) =>
          _EditJobSheet(job: job, service: _adminService),
    );

    if (saved == true && mounted) {
      _message('Job updated successfully.');
    }
  }

  Future<void> _deleteJob(Map<String, dynamic> job) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Delete job?'),
          content: Text(
            '"${_text(job['title'], 'This job')}" will be removed. '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _adminService.deleteJob(job['id'] as String);
      if (!mounted) return;
      _message('Job deleted successfully.');
    } catch (error) {
      if (!mounted) return;
      _message('Failed to delete job: $error', isError: true);
    }
  }

  Future<void> _toggleJobStatus(Map<String, dynamic> job) async {
    final newStatus = _statusOf(job) == 'Active' ? 'Closed' : 'Active';

    try {
      await _adminService.updateJob(job['id'] as String, {'status': newStatus});
      if (!mounted) return;
      _message('Job status changed to $newStatus.');
    } catch (error) {
      if (!mounted) return;
      _message('Failed to change status: $error', isError: true);
    }
  }

  Future<void> _showJobActions(Map<String, dynamic> job) {
    final isActive = _statusOf(job) == 'Active';

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 680),
      shape: _sheetShape,
      builder: (sheetContext) {
        Widget tile(
          IconData icon,
          String label,
          VoidCallback onTap, {
          Color color = _navy,
        }) {
          return ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: Icon(icon, color: color),
            title: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              onTap();
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    _text(job['title'], 'Untitled job'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                tile(Icons.visibility_outlined, 'View details',
                    () => _showJobDetails(job)),
                tile(Icons.edit_outlined, 'Edit job', () => _editJob(job)),
                if (widget.onViewCandidates != null)
                  tile(
                    Icons.people_outline,
                    'View candidates',
                    () => widget.onViewCandidates!(job['id'] as String),
                  ),
                tile(
                  isActive ? Icons.lock_outline : Icons.lock_open_outlined,
                  isActive ? 'Close job' : 'Activate job',
                  () => _toggleJobStatus(job),
                ),
                const Divider(color: _border),
                tile(
                  Icons.delete_outline,
                  'Delete job',
                  () => _deleteJob(job),
                  color: _red,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------- UI

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
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

  // Phone: the three numbers in one compact card.
  Widget _summaryStrip(int total, int active, int closed) {
    Widget stat(String label, int value, Color color) {
      return Expanded(
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      );
    }

    const divider = SizedBox(
      height: 34,
      child: VerticalDivider(width: 1, color: _border),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
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
      child: Row(
        children: [
          stat('Total', total, _navy),
          divider,
          stat('Active', active, _green),
          divider,
          stat('Closed', closed, _amber),
        ],
      ),
    );
  }

  Widget _searchField({String hint = 'Search jobs, skills, places...'}) {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
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

  Widget _filterChips(int total, int active, int closed) {
    Widget chip(String value, String label, int count) {
      final selected = selectedFilter == value;

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text('$label  $count'),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() => selectedFilter = value),
          backgroundColor: Colors.white,
          selectedColor: _blue,
          side: BorderSide(color: selected ? _blue : _border),
          labelStyle: TextStyle(
            color: selected ? Colors.white : _muted,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('All', 'All', total),
          chip('Active', 'Active', active),
          chip('Closed', 'Closed', closed),
        ],
      ),
    );
  }

  Widget _filterDropdown() {
    return DropdownButtonFormField<String>(
      key: ValueKey(selectedFilter),
      initialValue: selectedFilter,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Status',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: const [
        DropdownMenuItem(value: 'All', child: Text('All Jobs')),
        DropdownMenuItem(value: 'Active', child: Text('Active')),
        DropdownMenuItem(value: 'Closed', child: Text('Closed')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => selectedFilter = value);
      },
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _faint),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _jobCard(Map<String, dynamic> job) {
    final skills = _skillsOf(job);
    final created = _dateOf(job['createdAt']);
    final salary = _text(job['salary'], '');
    final match = _matchInfo(job);

    final subtitle = [
      _text(job['department'], ''),
      _text(job['jobType'], ''),
    ].where((part) => part.isNotEmpty).join('  •  ');

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showJobDetails(job),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.work_outline,
                          color: _blue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _text(job['title'], 'Untitled job'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _navy,
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                height: 1.25,
                              ),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusBadge(_statusOf(job)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _meta(Icons.place_outlined, _text(job['location'], 'No location')),
                      if (salary.isNotEmpty) _meta(Icons.payments_outlined, salary),
                      if (created != null) _meta(Icons.schedule, _timeAgo(created)),
                    ],
                  ),
                ),
                if (skills.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, right: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final skill in skills.take(3)) _skillChip(skill),
                        if (skills.length > 3) _skillChip('+${skills.length - 3}'),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Row(
                  children: [
                    Expanded(
                      child: match == null
                          ? const Text(
                              'Not matched yet',
                              style: TextStyle(color: _faint, fontSize: 12),
                            )
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: _chip(match.label, match.color),
                            ),
                    ),
                    if (widget.onViewCandidates != null)
                      TextButton.icon(
                        onPressed: () =>
                            widget.onViewCandidates!(job['id'] as String),
                        icon: const Icon(Icons.people_outline, size: 17),
                        label: const Text('Candidates'),
                      ),
                    IconButton(
                      tooltip: 'More actions',
                      onPressed: () => _showJobActions(job),
                      icon: const Icon(Icons.more_vert, color: _muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final hasFilter = _searchController.text.trim().isNotEmpty ||
        selectedFilter != 'All';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilter ? Icons.search_off : Icons.work_off_outlined,
                size: 32,
                color: _blue,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasFilter ? 'No jobs match your search' : 'No jobs yet',
              style: const TextStyle(
                color: _navy,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              hasFilter
                  ? 'Try a different search or status.'
                  : 'Create your first job and the AI will start matching.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _faint, fontSize: 12.5),
            ),
            if (!hasFilter && widget.onCreateJob != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.onCreateJob,
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
          ],
        ),
      ),
    );
  }

  Widget _jobCards(List<Map<String, dynamic>> visible, double contentWidth) {
    if (visible.isEmpty) return _emptyState();

    final columns = contentWidth >= 700 ? 2 : 1;
    const gap = 14.0;
    final width = (contentWidth - gap * (columns - 1)) / columns;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final job in visible)
          SizedBox(
            key: ValueKey(job['id']),
            width: width,
            child: _jobCard(job),
          ),
      ],
    );
  }

  // Wide screens keep the table.
  Widget _jobActionsMenu(Map<String, dynamic> job) {
    final isActive = _statusOf(job) == 'Active';

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: _muted),
      onSelected: (value) {
        if (value == 'view') _showJobDetails(job);
        if (value == 'edit') _editJob(job);
        if (value == 'candidates') {
          widget.onViewCandidates?.call(job['id'] as String);
        }
        if (value == 'status') _toggleJobStatus(job);
        if (value == 'delete') _deleteJob(job);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(children: [
            Icon(Icons.visibility_outlined, size: 18),
            SizedBox(width: 10),
            Text('View Details'),
          ]),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18),
            SizedBox(width: 10),
            Text('Edit Job'),
          ]),
        ),
        if (widget.onViewCandidates != null)
          const PopupMenuItem(
            value: 'candidates',
            child: Row(children: [
              Icon(Icons.people_outline, size: 18),
              SizedBox(width: 10),
              Text('View Candidates'),
            ]),
          ),
        PopupMenuItem(
          value: 'status',
          child: Row(children: [
            const Icon(Icons.swap_horiz, size: 18),
            const SizedBox(width: 10),
            Text(isActive ? 'Close Job' : 'Activate Job'),
          ]),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: Colors.red),
            SizedBox(width: 10),
            Text('Delete Job', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
    );
  }

  Widget _jobTable(List<Map<String, dynamic>> visible) {
    if (visible.isEmpty) return _emptyState();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        columnSpacing: 28,
        horizontalMargin: 18,
        columns: const [
          DataColumn(label: Text('JOB TITLE')),
          DataColumn(label: Text('LOCATION')),
          DataColumn(label: Text('TYPE')),
          DataColumn(label: Text('AI MATCHES')),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('ACTIONS')),
        ],
        rows: visible.map((job) {
          final match = _matchInfo(job);

          return DataRow(
            onSelectChanged: (_) => _showJobDetails(job),
            cells: [
              DataCell(
                SizedBox(
                  width: 190,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text(job['title'], 'Untitled'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _text(job['department'], 'N/A'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _faint, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(
                Text(
                  _text(job['location'], 'N/A'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  _text(job['jobType'], 'N/A'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                match == null
                    ? const Text('-', style: TextStyle(color: _faint))
                    : _chip(match.label, match.color, fontSize: 10.5),
              ),
              DataCell(_statusBadge(_statusOf(job))),
              DataCell(_jobActionsMenu(job)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _wideHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage Jobs',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _navy,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Manage, update and track all your job openings.',
                style: TextStyle(fontSize: 13, color: _muted),
              ),
            ],
          ),
        ),
        if (widget.onCreateJob != null)
          FilledButton.icon(
            onPressed: widget.onCreateJob,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New job'),
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _summaryCards(int total, int active, int closed) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard('Total Jobs', '$total', Icons.work_outline, _blue),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _summaryCard(
            'Active Jobs',
            '$active',
            Icons.check_circle_outline,
            _green,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _summaryCard(
            'Closed Jobs',
            '$closed',
            Icons.archive_outlined,
            _amber,
          ),
        ),
      ],
    );
  }

  Widget _filterPanel(List<Widget> below) {
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
            'All Job Openings',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _searchField(hint: 'Search by title, department or skill...'),
              ),
              const SizedBox(width: 14),
              SizedBox(width: 150, child: _filterDropdown()),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: _border),
          ...below,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _jobsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 44, color: _faint),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load jobs',
                    style: TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Firestore documents -> job maps (with their id).
        final jobs = snapshot.data!.docs
            .map((document) => {...document.data(), 'id': document.id})
            .toList();

        final visible = getFilteredJobs(jobs);
        final total = jobs.length;
        final active = jobs.where((job) => _statusOf(job) == 'Active').length;
        final closed = jobs.where((job) => _statusOf(job) == 'Closed').length;

        return Container(
          color: const Color(0xFFF5F7FC),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isPhone = constraints.maxWidth < 600;
              final isWide = constraints.maxWidth >= 900;
              final padding = isPhone ? 16.0 : 24.0;
              final contentWidth = (constraints.maxWidth - padding * 2)
                  .clamp(0.0, 1200.0)
                  .toDouble();

              final List<Widget> body;

              if (isPhone) {
                body = [
                  _summaryStrip(total, active, closed),
                  const SizedBox(height: 14),
                  _searchField(),
                  const SizedBox(height: 12),
                  _filterChips(total, active, closed),
                  const SizedBox(height: 16),
                  _jobCards(visible, contentWidth),
                ];
              } else if (isWide) {
                body = [
                  _wideHeader(),
                  const SizedBox(height: 24),
                  _summaryCards(total, active, closed),
                  const SizedBox(height: 24),
                  _filterPanel([_jobTable(visible)]),
                ];
              } else {
                body = [
                  _wideHeader(),
                  const SizedBox(height: 20),
                  _summaryCards(total, active, closed),
                  const SizedBox(height: 20),
                  _filterPanel([]),
                  const SizedBox(height: 16),
                  _jobCards(visible, contentWidth),
                ];
              }

              return SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: body,
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

// ------------------------------------------------------------ details sheet

class _JobDetailsSheet extends StatelessWidget {
  const _JobDetailsSheet({
    required this.job,
    required this.onEdit,
    required this.onToggleStatus,
    this.onViewCandidates,
  });

  final Map<String, dynamic> job;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback? onViewCandidates;

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _navy,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _faint, fontSize: 11)),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: _navy,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _matchSummary() {
    switch (job['matchStatus']) {
      case 'processing':
        return 'Matching is in progress...';
      case 'failed':
        return 'The last matching run failed. Open Candidates to try again.';
      case 'completed':
        {
          final when = _dateOf(job['matchedAt']);
          final evaluated = job['matchEvaluated'];
          final parts = [
            if (when != null) 'Last matched ${_timeAgo(when)}',
            if (evaluated is num) '${evaluated.toInt()} resumes evaluated',
          ];
          return parts.isEmpty ? 'Matched.' : parts.join('  •  ');
        }
    }
    return 'Not matched yet. Open Candidates to find suitable people.';
  }

  @override
  Widget build(BuildContext context) {
    final skills = _skillsOf(job);
    final created = _dateOf(job['createdAt']);
    final description = _text(job['description'], '');
    final responsibilities = _text(job['responsibilities'], '');
    final isActive = _statusOf(job) == 'Active';
    final match = _matchInfo(job);

    final subtitle = [
      _text(job['department'], ''),
      _text(job['jobType'], ''),
    ].where((part) => part.isNotEmpty).join('  •  ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text(job['title'], 'Untitled job'),
              style: const TextStyle(
                color: _navy,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: _muted, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusBadge(_statusOf(job)),
                if (match != null) _chip(match.label, match.color),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 12) / 2;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _infoTile('Location', _text(job['location']), width),
                    _infoTile('Salary', _text(job['salary']), width),
                    _infoTile('Experience', _text(job['experience']), width),
                    _infoTile('Education', _text(job['education']), width),
                    if (created != null)
                      _infoTile('Posted', _timeAgo(created), width),
                  ],
                );
              },
            ),
            if (skills.isNotEmpty) ...[
              _title('Required skills'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final skill in skills) _skillChip(skill)],
              ),
            ],
            if (description.isNotEmpty) ...[
              _title('Description'),
              Text(
                description,
                style: const TextStyle(color: _navy, fontSize: 13.5, height: 1.5),
              ),
            ],
            if (responsibilities.isNotEmpty) ...[
              _title('Responsibilities'),
              Text(
                responsibilities,
                style: const TextStyle(color: _navy, fontSize: 13.5, height: 1.5),
              ),
            ],
            _title('AI matching'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome, size: 17, color: _blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _matchSummary(),
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (onViewCandidates != null) ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: onViewCandidates,
                      icon: const Icon(Icons.people_outline, size: 18),
                      label: const Text('View candidates'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onToggleStatus,
                    icon: Icon(
                      isActive ? Icons.lock_outline : Icons.lock_open_outlined,
                      size: 18,
                    ),
                    label: Text(isActive ? 'Close job' : 'Activate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isActive ? _amber : _green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- edit sheet

class _EditJobSheet extends StatefulWidget {
  const _EditJobSheet({required this.job, required this.service});

  final Map<String, dynamic> job;
  final AdminService service;

  @override
  State<_EditJobSheet> createState() => _EditJobSheetState();
}

class _EditJobSheetState extends State<_EditJobSheet> {
  late final TextEditingController _title =
      TextEditingController(text: _text(widget.job['title'], ''));
  late final TextEditingController _department =
      TextEditingController(text: _text(widget.job['department'], ''));
  late final TextEditingController _location =
      TextEditingController(text: _text(widget.job['location'], ''));

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _department.dispose();
    _location.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty ||
        _department.text.trim().isEmpty ||
        _location.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in all three fields.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.service.updateJob(widget.job['id'] as String, {
        'title': _title.text.trim(),
        'department': _department.text.trim(),
        'location': _location.text.trim(),
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Failed to update job: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the form above the keyboard.
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit job',
              style: TextStyle(
                color: _navy,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Update the main details of this opening.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: _decoration('Job title', Icons.work_outline),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _department,
              textInputAction: TextInputAction.next,
              decoration: _decoration('Department', Icons.apartment_outlined),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _location,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: _decoration('Location', Icons.place_outlined),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: _red, fontSize: 12.5)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
