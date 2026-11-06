
import 'package:flutter/material.dart';

import '../services/admin_service.dart';

class ManageJobsScreen extends StatefulWidget {
  const ManageJobsScreen({super.key});

  @override
  State<ManageJobsScreen> createState() => _ManageJobsScreenState();
}

class _ManageJobsScreenState extends State<ManageJobsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AdminService _adminService = AdminService();

  String selectedFilter = 'All';

  final Color navy = const Color(0xFF172554);
  final Color blue = const Color(0xFF4F6EF7);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Search and filter actual Firestore jobs.
  List<Map<String, dynamic>> getFilteredJobs(
    List<Map<String, dynamic>> jobs,
  ) {
    final query = _searchController.text.toLowerCase();

    return jobs.where((job) {
      final title = (job['title'] ?? '').toString().toLowerCase();
      final department =
          (job['department'] ?? '').toString().toLowerCase();

      final matchesSearch =
          title.contains(query) || department.contains(query);

      final matchesFilter = selectedFilter == 'All' ||
          job['status'] == selectedFilter;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Widget summaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EDF5)),
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
                  style: TextStyle(
                    color: navy,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget statusBadge(String status) {
    final isActive = status == 'Active';

    final color = isActive
        ? const Color(0xFF059669)
        : const Color(0xFFDC6262);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void showJobDetails(Map<String, dynamic> job) {
    final skills = job['skills'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(job['title'] ?? 'Job Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Department: ${job['department'] ?? 'N/A'}'),
                const SizedBox(height: 10),
                Text('Location: ${job['location'] ?? 'N/A'}'),
                const SizedBox(height: 10),
                Text('Employment: ${job['jobType'] ?? 'N/A'}'),
                const SizedBox(height: 10),
                Text('Experience: ${job['experience'] ?? 'N/A'}'),
                const SizedBox(height: 10),
                Text('Education: ${job['education'] ?? 'N/A'}'),
                const SizedBox(height: 10),
                Text('Salary: ${job['salary'] ?? 'Not specified'}'),
                const SizedBox(height: 10),
                Text('Applicants: ${job['applicants'] ?? 0}'),
                const SizedBox(height: 10),
                Text('Description: ${job['description'] ?? 'N/A'}'),
                const SizedBox(height: 10),
                Text(
                  'Skills: ${skills is List ? skills.join(', ') : skills ?? 'N/A'}',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Status: '),
                    statusBadge(job['status'] ?? 'Active'),
                  ],
                ),
              ],
            ),
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

  Future<void> editJob(Map<String, dynamic> job) async {
    final titleController =
        TextEditingController(text: job['title'] ?? '');

    final departmentController =
        TextEditingController(text: job['department'] ?? '');

    final locationController =
        TextEditingController(text: job['location'] ?? '');

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Job'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Job Title',
                  ),
                ),
                TextField(
                  controller: departmentController,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                  ),
                ),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty ||
                    departmentController.text.trim().isEmpty ||
                    locationController.text.trim().isEmpty) {
                  return;
                }

                try {
                  await _adminService.updateJob(
                    job['id'],
                    {
                      'title': titleController.text.trim(),
                      'department': departmentController.text.trim(),
                      'location': locationController.text.trim(),
                    },
                  );

                  if (!mounted) return;

                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Job updated successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update job: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    departmentController.dispose();
    locationController.dispose();
  }

  Future<void> deleteJob(Map<String, dynamic> job) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Job?'),
          content: Text(
            'Are you sure you want to delete "${job['title']}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _adminService.deleteJob(job['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job deleted successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete job: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> toggleJobStatus(Map<String, dynamic> job) async {
    final newStatus =
        job['status'] == 'Active' ? 'Closed' : 'Active';

    try {
      await _adminService.updateJob(
        job['id'],
        {'status': newStatus},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Job status changed to $newStatus.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to change status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget jobActions(Map<String, dynamic> job) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_horiz,
        color: Color(0xFF64748B),
      ),
      onSelected: (value) {
        if (value == 'view') showJobDetails(job);
        if (value == 'edit') editJob(job);
        if (value == 'status') toggleJobStatus(job);
        if (value == 'delete') deleteJob(job);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18),
              SizedBox(width: 10),
              Text('View Details'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('Edit Job'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'status',
          child: Row(
            children: [
              const Icon(Icons.swap_horiz, size: 18),
              const SizedBox(width: 10),
              Text(
                job['status'] == 'Active'
                    ? 'Close Job'
                    : 'Activate Job',
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red,
              ),
              SizedBox(width: 10),
              Text(
                'Delete Job',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget jobTable(List<Map<String, dynamic>> visibleJobs) {
    if (visibleJobs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(45),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.work_off_outlined,
                size: 45,
                color: Color(0xFF94A3B8),
              ),
              SizedBox(height: 12),
              Text(
                'No jobs found',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Create a job or change your search/filter.',
                textAlign: TextAlign.center,
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          const Color(0xFFF8FAFC),
        ),
        columnSpacing: 28,
        horizontalMargin: 18,
        columns: const [
          DataColumn(label: Text('JOB TITLE')),
          DataColumn(label: Text('LOCATION')),
          DataColumn(label: Text('TYPE')),
          DataColumn(label: Text('APPLICANTS')),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('ACTIONS')),
        ],
        rows: visibleJobs.map((job) {
          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 180,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['title'] ?? 'Untitled',
                        style: TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        job['department'] ?? 'N/A',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(
                Text(
                  job['location'] ?? 'N/A',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  job['jobType'] ?? 'N/A',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              DataCell(
                Text(
                  '${job['applicants'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DataCell(
                statusBadge(job['status'] ?? 'Active'),
              ),
              DataCell(jobActions(job)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget filterDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: selectedFilter,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Status',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: 'All',
          child: Text('All Jobs'),
        ),
        DropdownMenuItem(
          value: 'Active',
          child: Text('Active'),
        ),
        DropdownMenuItem(
          value: 'Closed',
          child: Text('Closed'),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => selectedFilter = value);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _adminService.getJobs(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error loading jobs:\n${snapshot.error}',
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

        // Convert Firestore documents into job maps.
        final jobs = snapshot.data!.docs.map((document) {
          return {
            ...document.data(),
            'id': document.id,
          };
        }).toList();

        final visibleJobs = getFilteredJobs(jobs);

        final activeJobs =
            jobs.where((job) => job['status'] == 'Active').length;

        final closedJobs =
            jobs.where((job) => job['status'] == 'Closed').length;

        return Container(
          color: const Color(0xFFF5F7FC),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manage Jobs',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172554),
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Manage, update and track all your job openings.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),

                // Summary cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 700
                        ? 3
                        : constraints.maxWidth >= 450
                            ? 2
                            : 1;

                    const gap = 14.0;

                    final width = (constraints.maxWidth -
                            gap * (columns - 1)) /
                        columns;

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(
                          width: width,
                          child: summaryCard(
                            'Total Jobs',
                            '${jobs.length}',
                            Icons.work_outline,
                            blue,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: summaryCard(
                            'Active Jobs',
                            '$activeJobs',
                            Icons.check_circle_outline,
                            const Color(0xFF059669),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: summaryCard(
                            'Closed Jobs',
                            '$closedJobs',
                            Icons.archive_outlined,
                            const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 25),

                // Jobs table and filters
                Container(
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
                        'All Job Openings',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172554),
                        ),
                      ),
                      const SizedBox(height: 18),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 500) {
                            return Column(
                              children: [
                                TextField(
                                  controller: _searchController,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: 'Search jobs...',
                                    prefixIcon:
                                        const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                filterDropdown(),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search by job title or department...',
                                    prefixIcon:
                                        const Icon(Icons.search),
                                    filled: true,
                                    fillColor:
                                        const Color(0xFFFAFBFE),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              SizedBox(
                                width: 150,
                                child: filterDropdown(),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 20),
                      const Divider(
                        color: Color(0xFFE9EDF5),
                      ),

                      jobTable(visibleJobs),
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
