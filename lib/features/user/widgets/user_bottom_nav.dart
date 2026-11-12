import 'package:flutter/material.dart';

import 'user_ui.dart';

/// Phone navigation for candidates: Home, Jobs and Analytics.
/// Same look as the admin bottom bar.
class UserBottomNav extends StatelessWidget {
  const UserBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: UserUi.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14172554),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(
              children: [
                _item(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                ),
                _item(
                  icon: Icons.work_outline,
                  activeIcon: Icons.work,
                  label: 'Jobs',
                  index: 1,
                ),
                _item(
                  icon: Icons.insights_outlined,
                  activeIcon: Icons.insights_rounded,
                  label: 'Analytics',
                  index: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final selected = selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => onSelected(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? UserUi.blue.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: 23,
                color: selected ? UserUi.blue : UserUi.faint,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? UserUi.blue : UserUi.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
