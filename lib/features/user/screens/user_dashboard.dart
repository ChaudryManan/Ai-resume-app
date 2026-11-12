import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/user_actions.dart';
import '../services/user_insights_controller.dart';
import '../widgets/user_bottom_nav.dart';
import '../widgets/user_topbar.dart';
import '../widgets/user_ui.dart';
import 'user_analytics_screen.dart';
import 'user_home_screen.dart';
import 'user_jobs_screen.dart';

/// The candidate app: Home (resume + profile), Jobs and Analytics.
class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  static const List<String> _titles = ['Home', 'Jobs', 'Analytics'];

  int _index = 0;

  // Pages are built the first time they are opened, then kept alive.
  final Set<int> _visited = {0};

  final UserInsightsController _insights = UserInsightsController();
  late final UserActions _actions = UserActions(_insights);

  @override
  void initState() {
    super.initState();
    // Home needs the profile straight away.
    _insights.load();
  }

  @override
  void dispose() {
    _actions.dispose();
    _insights.dispose();
    super.dispose();
  }

  String get _userName {
    final name = FirebaseAuth.instance.currentUser?.displayName;

    if (name == null || name.trim().isEmpty) return 'Candidate';

    return name;
  }

  void _select(int index) {
    if (index == _index) return;

    setState(() {
      _index = index;
      _visited.add(index);
    });

    // A recruiter may have run matching since the last visit.
    if (index == 2) _insights.refreshIfStale();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Log out?'),
          content: const Text(
            'You will need to sign in again to apply for jobs.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: UserUi.red),
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

  Widget _page(int index) {
    if (!_visited.contains(index)) return const SizedBox.shrink();

    switch (index) {
      case 0:
        return UserHomeScreen(
          actions: _actions,
          insights: _insights,
          onNavigate: _select,
        );
      case 1:
        return UserJobsScreen(actions: _actions, insights: _insights);
      default:
        return UserAnalyticsScreen(
          insights: _insights,
          onGoHome: () => _select(0),
          onGoJobs: () => _select(1),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;

    // The keyboard would push the bottom bar on top of the search box.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    final user = FirebaseAuth.instance.currentUser;

    return PopScope(
      // Back goes to Home first, and only then leaves the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        backgroundColor: UserUi.background,
        bottomNavigationBar: (compact && !keyboardOpen)
            ? UserBottomNav(selectedIndex: _index, onSelected: _select)
            : null,
        body: Column(
          children: [
            UserTopbar(
              title: _titles[_index],
              compact: compact,
              selectedIndex: _index,
              onSelected: _select,
              onLogout: _confirmLogout,
              userName: _userName,
              email: user?.email,
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: List<Widget>.generate(3, _page),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
