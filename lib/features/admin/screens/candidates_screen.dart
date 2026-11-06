
import 'package:flutter/material.dart';

class CandidatesScreen extends StatefulWidget {
  const CandidatesScreen({super.key});

  @override
  State<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends State<CandidatesScreen> {
  final TextEditingController searchController = TextEditingController();

  String selectedFilter = 'All';

  final Color navy = const Color(0xFF172554);
  final Color blue = const Color(0xFF4F6EF7);

  final List<Map<String, dynamic>> candidates = [
    {
      'name': 'Ali Ahmed',
      'email': 'ali.ahmed@gmail.com',
      'job': 'AI Engineer',
      'experience': '2 Years',
      'education': 'BS Computer Science',
      'skills': ['Python', 'TensorFlow', 'NLP'],
      'score': 94,
      'status': 'Shortlisted',
    },
    {
      'name': 'Sara Khan',
      'email': 'sara.khan@gmail.com',
      'job': 'Flutter Developer',
      'experience': '1 Year',
      'education': 'BS Software Engineering',
      'skills': ['Flutter', 'Dart', 'Firebase'],
      'score': 87,
      'status': 'Pending',
    },
    {
      'name': 'Usman Tariq',
      'email': 'usman.tariq@gmail.com',
      'job': 'Python Developer',
      'experience': '3 Years',
      'education': 'MS Computer Science',
      'skills': ['Python', 'FastAPI', 'SQL'],
      'score': 78,
      'status': 'Pending',
    },
    {
      'name': 'Ayesha Malik',
      'email': 'ayesha.malik@gmail.com',
      'job': 'AI Engineer',
      'experience': 'Fresh Graduate',
      'education': 'BS Artificial Intelligence',
      'skills': ['Machine Learning', 'Python', 'Pandas'],
      'score': 72,
      'status': 'Rejected',
    },
    {
      'name': 'Hamza Raza',
      'email': 'hamza.raza@gmail.com',
      'job': 'Flutter Developer',
      'experience': '2 Years',
      'education': 'BS Computer Science',
      'skills': ['Flutter', 'Dart', 'REST API'],
      'score': 91,
      'status': 'Pending',
    },
  ];

  List<Map<String, dynamic>> get filteredCandidates {
    final query = searchController.text.toLowerCase();

    return candidates.where((candidate) {
      final matchesSearch =
          candidate['name'].toString().toLowerCase().contains(query) ||
          candidate['email'].toString().toLowerCase().contains(query) ||
          candidate['job'].toString().toLowerCase().contains(query);

      final matchesFilter = selectedFilter == 'All' ||
          candidate['status'] == selectedFilter;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  int get shortlistedCount =>
      candidates.where((c) => c['status'] == 'Shortlisted').length;

  int get pendingCount =>
      candidates.where((c) => c['status'] == 'Pending').length;

  int get rejectedCount =>
      candidates.where((c) => c['status'] == 'Rejected').length;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Widget summaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(17),
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
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
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
    Color color;

    switch (status) {
      case 'Shortlisted':
        color = const Color(0xFF059669);
        break;
      case 'Rejected':
        color = const Color(0xFFDC6262);
        break;
      default:
        color = const Color(0xFFD97706);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  Widget scoreBadge(int score) {
    Color color;

    if (score >= 85) {
      color = const Color(0xFF059669);
    } else if (score >= 70) {
      color = const Color(0xFFD97706);
    } else {
      color = const Color(0xFFDC6262);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$score%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void updateStatus(Map<String, dynamic> candidate, String status) {
    setState(() {
      candidate['status'] = status;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${candidate['name']} marked as $status.'),
      ),
    );
  }

  void showCandidateDetails(Map<String, dynamic> candidate) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(candidate['name']),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(candidate['email']),
                const SizedBox(height: 18),
                const Text(
                  'Applied Position',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(candidate['job']),
                const SizedBox(height: 14),
                const Text(
                  'Education',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(candidate['education']),
                const SizedBox(height: 14),
                const Text(
                  'Experience',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(candidate['experience']),
                const SizedBox(height: 14),
                const Text(
                  'Skills',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (candidate['skills'] as List<String>)
                      .map((skill) => Chip(label: Text(skill)))
                      .toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'ATS Matching Score',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                scoreBadge(candidate['score']),
                const SizedBox(height: 14),
                const Text(
                  'Application Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                statusBadge(candidate['status']),
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

  Widget candidateActions(Map<String, dynamic> candidate) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: Color(0xFF64748B)),
      onSelected: (value) {
        if (value == 'view') {
          showCandidateDetails(candidate);
        } else if (value == 'shortlist') {
          updateStatus(candidate, 'Shortlisted');
        } else if (value == 'reject') {
          updateStatus(candidate, 'Rejected');
        } else if (value == 'pending') {
          updateStatus(candidate, 'Pending');
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'view',
          child: Text('View Profile'),
        ),
        PopupMenuItem(
          value: 'shortlist',
          child: Text('Shortlist Candidate'),
        ),
        PopupMenuItem(
          value: 'reject',
          child: Text('Reject Candidate'),
        ),
        PopupMenuItem(
          value: 'pending',
          child: Text('Mark as Pending'),
        ),
      ],
    );
  }

  Widget candidateTable() {
    final visibleCandidates = filteredCandidates;

    if (visibleCandidates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.person_search_outlined,
                size: 45,
                color: Color(0xFF94A3B8),
              ),
              SizedBox(height: 12),
              Text(
                'No candidates found',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
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
        columnSpacing: 25,
        columns: const [
          DataColumn(label: Text('CANDIDATE')),
          DataColumn(label: Text('APPLIED POSITION')),
          DataColumn(label: Text('EXPERIENCE')),
          DataColumn(label: Text('ATS SCORE')),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('ACTIONS')),
        ],
        rows: visibleCandidates.map((candidate) {
          final initials = candidate['name']
              .toString()
              .split(' ')
              .map((part) => part[0])
              .take(2)
              .join();

          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 185,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFEEF2FF),
                        child: Text(
                          initials,
                          style: TextStyle(
                            color: blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              candidate['name'],
                              style: TextStyle(
                                color: navy,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              candidate['email'],
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(Text(
                candidate['job'],
                style: const TextStyle(fontSize: 12),
              )),
              DataCell(Text(
                candidate['experience'],
                style: const TextStyle(fontSize: 12),
              )),
              DataCell(scoreBadge(candidate['score'])),
              DataCell(statusBadge(candidate['status'])),
              DataCell(candidateActions(candidate)),
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
        labelText: 'Application Status',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'All', child: Text('All Candidates')),
        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
        DropdownMenuItem(value: 'Shortlisted', child: Text('Shortlisted')),
        DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
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
                color: Color(0xFF172554),
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Review applicants and manage your recruitment pipeline.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700
                    ? 4
                    : constraints.maxWidth >= 450
                        ? 2
                        : 1;

                const gap = 12.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: width,
                      child: summaryCard(
                        'Total Candidates',
                        '${candidates.length}',
                        Icons.people_outline,
                        blue,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: summaryCard(
                        'Pending Review',
                        '$pendingCount',
                        Icons.pending_actions,
                        const Color(0xFFD97706),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: summaryCard(
                        'Shortlisted',
                        '$shortlistedCount',
                        Icons.check_circle_outline,
                        const Color(0xFF059669),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: summaryCard(
                        'Rejected',
                        '$rejectedCount',
                        Icons.cancel_outlined,
                        const Color(0xFFDC6262),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 25),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFE9EDF5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'All Applicants',
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
                              controller: searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search candidates...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
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
                              controller: searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search by name, email or position...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 190,
                            child: filterDropdown(),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE9EDF5)),
                  candidateTable(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
