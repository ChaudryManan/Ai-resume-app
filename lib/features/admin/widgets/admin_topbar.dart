import 'package:flutter/material.dart';

class AdminTopbar extends StatelessWidget {
  final String title;
  final VoidCallback onLogout;

  /// Phone layout: brand mark, two-line title and an account menu.
  final bool compact;

  const AdminTopbar({
    super.key,
    required this.title,
    required this.onLogout,
    this.compact = false,
  });

  static const Color navy = Color(0xFF172554);
  static const Color blue = Color(0xFF4F6EF7);

  void _showNotifications(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No new notifications.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EDF5))),
      ),
      // Keeps the bar below the phone's status bar and notch.
      child: SafeArea(
        bottom: false,
        child: compact ? _compactBar(context) : _wideBar(context),
      ),
    );
  }

  Widget _compactBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B93FF), blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: blue.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.work_outline, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HIREFLOW ADMIN',
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: navy,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _showNotifications(context),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF64748B),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) {
              if (value == 'logout') onLogout();
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  'Administrator',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: navy,
                  ),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Color(0xFFDC6262)),
                    SizedBox(width: 10),
                    Text('Log out', style: TextStyle(color: Color(0xFFDC6262))),
                  ],
                ),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFFEEF2FF),
                child: Icon(Icons.person, color: blue, size: 19),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wideBar(BuildContext context) {
    return Container(
      height: 75,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showNotifications(context),
            icon: const Icon(
              Icons.notifications_none,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFEEF2FF),
            child: Icon(Icons.person, color: blue, size: 20),
          ),
          const SizedBox(width: 10),
          if (MediaQuery.sizeOf(context).width > 500)
            const Text(
              'Administrator',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Logout',
            onPressed: onLogout,
            icon: const Icon(Icons.logout, color: Color(0xFFDC6262)),
          ),
        ],
      ),
    );
  }
}
