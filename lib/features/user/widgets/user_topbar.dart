import 'package:flutter/material.dart';

import 'user_ui.dart';

/// Top bar for candidates.
///  * phone:  brand tile, page title and an account menu
///  * wide:   brand, the three page tabs and an account menu
class UserTopbar extends StatelessWidget {
  const UserTopbar({
    super.key,
    required this.title,
    required this.compact,
    required this.selectedIndex,
    required this.onSelected,
    required this.onLogout,
    required this.userName,
    this.email,
  });

  final String title;
  final bool compact;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  final String userName;
  final String? email;

  static const List<_Tab> _tabs = [
    _Tab('Home', Icons.home_outlined, Icons.home_rounded),
    _Tab('Jobs', Icons.work_outline, Icons.work),
    _Tab('Analytics', Icons.insights_outlined, Icons.insights_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: UserUi.border)),
      ),
      // Keeps the bar below the phone's status bar and notch.
      child: SafeArea(
        bottom: false,
        child: compact ? _compactBar() : _wideBar(),
      ),
    );
  }

  Widget _brandTile() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B93FF), UserUi.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: UserUi.blue.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.work_outline, color: Colors.white, size: 20),
    );
  }

  Widget _compactBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: Row(
        children: [
          _brandTile(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HIREFLOW',
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: UserUi.faint,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: UserUi.navy,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          _accountMenu(showName: false),
        ],
      ),
    );
  }

  Widget _wideBar() {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          _brandTile(),
          const SizedBox(width: 12),
          const Text(
            'HireFlow',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: UserUi.navy,
            ),
          ),
          const SizedBox(width: 36),
          for (var i = 0; i < _tabs.length; i++) ...[
            _tabButton(i),
            const SizedBox(width: 6),
          ],
          const Spacer(),
          _accountMenu(showName: true),
        ],
      ),
    );
  }

  Widget _tabButton(int index) {
    final tab = _tabs[index];
    final selected = selectedIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? UserUi.blue.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              selected ? tab.activeIcon : tab.icon,
              size: 20,
              color: selected ? UserUi.blue : UserUi.muted,
            ),
            const SizedBox(width: 8),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? UserUi.blue : UserUi.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountMenu({required bool showName}) {
    final avatar = CircleAvatar(
      radius: 17,
      backgroundColor: const Color(0xFFEEF2FF),
      child: Text(
        UserUi.initialOf(userName),
        style: const TextStyle(
          color: UserUi.blue,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        if (value == 'logout') onLogout();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: UserUi.navy,
                ),
              ),
              if (email != null && email!.isNotEmpty)
                Text(
                  email!,
                  style: const TextStyle(fontSize: 12, color: UserUi.muted),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: UserUi.red),
              SizedBox(width: 10),
              Text('Log out', style: TextStyle(color: UserUi.red)),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: showName
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  avatar,
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: UserUi.navy,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: UserUi.muted,
                  ),
                ],
              )
            : avatar,
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
