import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  static const navy = Color(0xFF172554);
  static const blue = Color(0xFF4F6EF7);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE9EDF5);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please sign in.'));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('createdBy', isEqualTo: uid)
          .snapshots(),
      builder: (context, jobsSnap) {
        if (jobsSnap.hasError) return _error('Could not load jobs: ${jobsSnap.error}');
        if (!jobsSnap.hasData) return const Center(child: CircularProgressIndicator());

        final jobs = jobsSnap.data!.docs;
        final jobIds = jobs.map((e) => e.id).toSet();
        final activeJobs = jobs.where((e) => (e.data()['status'] ?? 'Active') == 'Active').length;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('applications').snapshots(),
          builder: (context, appsSnap) {
            if (appsSnap.hasError) return _error('Could not load applications: ${appsSnap.error}');
            if (!appsSnap.hasData) return const Center(child: CircularProgressIndicator());

            // Application records are linked to jobs through jobId.
            final apps = appsSnap.data!.docs
                .map((e) => e.data())
                .where((e) => jobIds.contains((e['jobId'] ?? '').toString()))
                .toList();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'user')
                  .snapshots(),
              builder: (context, usersSnap) {
                if (usersSnap.hasError) return _error('Could not load candidates: ${usersSnap.error}');
                if (!usersSnap.hasData) return const Center(child: CircularProgressIndicator());
                return _content(context, jobs.length, activeJobs, apps, usersSnap.data!.docs.length);
              },
            );
          },
        );
      },
    );
  }

  Widget _error(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: muted)),
        ),
      );

  Widget _content(BuildContext context, int totalJobs, int activeJobs,
      List<Map<String, dynamic>> apps, int candidates) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    final padding = compact ? 16.0 : 25.0;
    final innerWidth = (width - padding * 2).clamp(0.0, 1100.0);
    final columns = innerWidth >= 760 ? 4 : 2;
    const gap = 12.0;
    final cardWidth = (innerWidth - gap * (columns - 1)) / columns;

    final statuses = <String, int>{};
    final jobsByTitle = <String, int>{};
    final months = List<int>.filled(6, 0);
    final labels = <String>[];
    final now = DateTime.now();
    for (var i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      labels.add(_month(date.month));
    }
    for (final app in apps) {
      final rawStatus = (app['status'] ?? 'Pending').toString().trim();
      final status = rawStatus.isEmpty
          ? 'Pending'
          : rawStatus[0].toUpperCase() + rawStatus.substring(1).toLowerCase();
      statuses[status] = (statuses[status] ?? 0) + 1;
      final title = (app['jobTitle'] ?? 'Untitled job').toString();
      jobsByTitle[title] = (jobsByTitle[title] ?? 0) + 1;
      final appliedAt = app['appliedAt'];
      if (appliedAt is Timestamp) {
        final date = appliedAt.toDate();
        final ago = (now.year - date.year) * 12 + now.month - date.month;
        if (ago >= 0 && ago < 6) months[5 - ago]++;
      }
    }
    final shortlisted = statuses.entries
        .where((e) => e.key.toLowerCase() == 'shortlisted')
        .fold<int>(0, (sum, e) => sum + e.value);
    final popular = jobsByTitle.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final stats = [
      _Metric('Total Applications', apps.length, 'Applications for your jobs', Icons.description_outlined, blue),
      _Metric('Shortlisted', shortlisted, 'Candidates shortlisted', Icons.check_circle_outline, const Color(0xFF059669)),
      _Metric('Active Jobs', activeJobs, 'Currently accepting', Icons.work_outline, const Color(0xFF0D9488)),
      _Metric('Candidates', candidates, 'Registered candidate accounts', Icons.people_outline, const Color(0xFFD97706)),
    ];

    return Container(
      color: const Color(0xFFF5F7FC),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recruitment Analytics',
                    style: TextStyle(color: navy, fontSize: compact ? 24 : 27,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Live statistics calculated from your Firestore records.',
                    style: TextStyle(color: muted, fontSize: 13)),
                const SizedBox(height: 22),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: stats.map((m) => SizedBox(
                    width: cardWidth,
                    child: _statCard(m, compact),
                  )).toList(),
                ),
                const SizedBox(height: 18),
                _section('Application Activity',
                    'Applications received in the last six calendar months',
                    _monthlyChart(months, labels)),
                const SizedBox(height: 16),
                _section('Application Status',
                    'Current status of applications for your jobs',
                    _statusChart(statuses, apps.length)),
                const SizedBox(height: 16),
                _section('Most Popular Jobs',
                    'Jobs ranked by actual application count',
                    _popularJobs(popular.take(5).toList())),
                const SizedBox(height: 16),
                _section('Data Included',
                    'The records used to calculate these analytics',
                    Column(children: [
                      _summaryRow('Jobs created by you', totalJobs),
                      _summaryRow('Applications linked to your jobs', apps.length),
                      _summaryRow('Registered candidate accounts', candidates),
                    ])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _month(int month) {
    const names = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return names[month - 1];
  }

  Widget _statCard(_Metric m, bool compact) => Container(
    padding: EdgeInsets.all(compact ? 14 : 18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: m.color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(11)),
        child: Icon(m.icon, color: m.color, size: 20)),
      SizedBox(height: compact ? 12 : 16),
      Text(m.value.toString(), style: TextStyle(color: navy,
          fontSize: compact ? 26 : 30, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: navy, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 3),
      Text(m.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: muted, fontSize: 11)),
    ]),
  );

  Widget _section(String title, String subtitle, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
      const SizedBox(height: 20),
      child,
    ]),
  );

  Widget _monthlyChart(List<int> counts, List<String> labels) {
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);
    return SizedBox(height: 210, child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(counts.length, (i) => Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(counts[i].toString(), style: const TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 6),
          Container(height: maxCount == 0 ? 0 : counts[i] / maxCount * 140,
            width: double.infinity,
            decoration: const BoxDecoration(color: blue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)))),
          const SizedBox(height: 8),
          Text(labels[i], style: const TextStyle(color: muted, fontSize: 10)),
        ]),
      ))),
    ));
  }

  Widget _statusChart(Map<String, int> statuses, int total) {
    const colors = [Color(0xFFD97706), Color(0xFF059669), Color(0xFFDC6262),
      Color(0xFF4F6EF7), Color(0xFF8B5CF6)];
    final entries = statuses.entries.toList();
    if (entries.isEmpty) {
      return const Text('No applications have been submitted yet.',
          style: TextStyle(color: muted, fontSize: 13));
    }
    return Column(children: [
      if (total > 0) ClipRRect(borderRadius: BorderRadius.circular(8),
        child: Row(children: List.generate(entries.length, (i) => Expanded(
          flex: entries[i].value,
          child: Container(height: 15, color: colors[i % colors.length]))))),
      const SizedBox(height: 18),
      ...List.generate(entries.length, (i) {
        final e = entries[i];
        final pct = total == 0 ? '0.0' : (e.value / total * 100).toStringAsFixed(1);
        return Padding(padding: const EdgeInsets.only(bottom: 13),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(
              color: colors[i % colors.length], shape: BoxShape.circle)),
            const SizedBox(width: 9),
            Expanded(child: Text(e.key, style: const TextStyle(color: muted, fontSize: 13))),
            Text(e.value.toString(), style: const TextStyle(color: navy, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            SizedBox(width: 48, child: Text('$pct%', textAlign: TextAlign.right,
              style: const TextStyle(color: muted, fontSize: 11))),
          ]));
      }),
    ]);
  }

  Widget _popularJobs(List<MapEntry<String, int>> jobs) {
    if (jobs.isEmpty) return const Text('No applications have been submitted yet.',
        style: TextStyle(color: muted, fontSize: 13));
    final max = jobs.first.value;
    return Column(children: jobs.map((job) => Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(job.key, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: navy, fontSize: 13, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Text('${job.value} applications', style: const TextStyle(color: muted, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(value: job.value / max, minHeight: 9,
            backgroundColor: const Color(0xFFEEF2F7), color: const Color(0xFF0D9488))),
      ]),
    )).toList());
  }

  Widget _summaryRow(String label, int value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: muted, fontSize: 13))),
      Text(value.toString(), style: const TextStyle(color: navy, fontWeight: FontWeight.w800)),
    ]),
  );
}

class _Metric {
  const _Metric(this.title, this.value, this.subtitle, this.icon, this.color);
  final String title;
  final int value;
  final String subtitle;
  final IconData icon;
  final Color color;
}
