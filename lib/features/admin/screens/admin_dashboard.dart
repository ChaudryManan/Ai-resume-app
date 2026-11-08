import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';

import '../widgets/admin_bottom_nav.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/admin_topbar.dart';

import 'overview_screen.dart';
import 'create_job_screen.dart';
import 'manage_jobs_screen.dart';
import 'candidates_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const Color _navy = Color(0xFF172554);
  static const Color _blue = Color(0xFF4F6EF7);

  int selectedIndex = 0;

  final List<String> pageTitles = [
    'Overview',
    'Create Job',
    'Manage Jobs',
    'Candidates',
    'Analytics',
    'Settings',
  ];

  // Built once (not on every rebuild) so pages keep their streams alive.
  // The Overview gets a callback so its buttons can open other pages.
  // "View candidates" on a job card asks the Candidates page to open that job.
  final ValueNotifier<String?> _candidatesJobRequest =
      ValueNotifier<String?>(null);

  late final List<Widget> pages = [
    OverviewScreen(onNavigate: _select),
    CreateJobScreen(
      onViewCandidates: _openCandidatesFor,
      onViewJobs: () => _select(2),
    ),
    ManageJobsScreen(
      onViewCandidates: _openCandidatesFor,
      onCreateJob: () => _select(1),
    ),
    CandidatesScreen(requestedJobId: _candidatesJobRequest),
    const AnalyticsScreen(),
    const SettingsScreen(),
  ];

  @override
  void dispose() {
    _candidatesJobRequest.dispose();
    super.dispose();
  }

  void _openCandidatesFor(String jobId) {
    _candidatesJobRequest.value = jobId;
    _select(3);
  }

  Future<void> logout() async {
    await AuthService().logout();
  }

  void _select(int index) {
    if (index == selectedIndex) return;
    setState(() => selectedIndex = index);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Log out?'),
          content: const Text(
            'You will need to sign in again to manage jobs and candidates.',
          ),
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
      await logout();
    }
  }

  Widget _moreTile({
    required BuildContext sheetContext,
    required IconData icon,
    required String label,
    required String caption,
    required int index,
  }) {
    final selected = selectedIndex == index;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: selected ? _blue.withValues(alpha: 0.08) : null,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: _blue, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, color: _navy),
      ),
      subtitle: Text(
        caption,
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFF94A3B8),
      ),
      onTap: () {
        Navigator.pop(sheetContext);
        _select(index);
      },
    );
  }

  Future<void> _showMoreSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _moreTile(
                  sheetContext: sheetContext,
                  icon: Icons.analytics_outlined,
                  label: 'Analytics',
                  caption: 'Hiring numbers and trends',
                  index: 4,
                ),
                const SizedBox(height: 6),
                _moreTile(
                  sheetContext: sheetContext,
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  caption: 'Account and preferences',
                  index: 5,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: Color(0xFFE9EDF5), height: 1),
                ),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEECEC),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: Color(0xFFDC6262),
                      size: 21,
                    ),
                  ),
                  title: const Text(
                    'Log out',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC6262),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmLogout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 850;
    final isMobile = width < 600;
    final isTablet = !isDesktop && !isMobile;

    // The keyboard would push the bottom bar on top of a form, so hide it.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      // Back goes to Overview first, and only then leaves the app.
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() => selectedIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FC),
        bottomNavigationBar: (isMobile && !keyboardOpen)
            ? AdminBottomNav(
                selectedIndex: selectedIndex,
                onSelected: _select,
                onMore: _showMoreSheet,
              )
            : null,
        body: Row(
          children: [
            if (!isMobile)
              AdminSidebar(
                compact: isTablet,
                selectedIndex: selectedIndex,
                onItemSelected: (index) {
                  if (index == 6) {
                    logout();
                  } else {
                    _select(index);
                  }
                },
              ),
            Expanded(
              child: Column(
                children: [
                  AdminTopbar(
                    title: pageTitles[selectedIndex],
                    compact: isMobile,
                    onLogout: isMobile ? _confirmLogout : logout,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<int>(selectedIndex),
                        child: pages[selectedIndex],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
