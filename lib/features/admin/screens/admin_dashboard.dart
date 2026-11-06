
import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';

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
  int selectedIndex = 0;

  final List<String> pageTitles = [
    'Overview',
    'Create Job',
    'Manage Jobs',
    'Candidates',
    'Analytics',
    'Settings',
  ];

  final List<Widget> pages = const [
    OverviewScreen(),
    CreateJobScreen(),
    ManageJobsScreen(),
    CandidatesScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  Future<void> logout() async {
    await AuthService().logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 850;

          return Row(
            children: [
              if (isDesktop)
                AdminSidebar(
                  selectedIndex: selectedIndex,
                  onItemSelected: (index) {
                    if (index == 6) {
                      logout();
                    } else {
                      setState(() {
                        selectedIndex = index;
                      });
                    }
                  },
                ),

              Expanded(
                child: Column(
                  children: [
                    AdminTopbar(
                      title: pageTitles[selectedIndex],
                      onLogout: logout,
                    ),
                    Expanded(
                      child: pages[selectedIndex],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
