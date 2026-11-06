
import 'package:flutter/material.dart';

class AdminTopbar extends StatelessWidget {
  final String title;
  final VoidCallback onLogout;

  const AdminTopbar({
    super.key,
    required this.title,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 75,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE9EDF5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172554),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No new notifications.'),
                ),
              );
            },
            icon: const Icon(
              Icons.notifications_none,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFEEF2FF),
            child: Icon(
              Icons.person,
              color: Color(0xFF4F6EF7),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          if (MediaQuery.sizeOf(context).width > 500)
            const Text(
              'Administrator',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Logout',
            onPressed: onLogout,
            icon: const Icon(
              Icons.logout,
              color: Color(0xFFDC6262),
            ),
          ),
        ],
      ),
    );
  }
}
