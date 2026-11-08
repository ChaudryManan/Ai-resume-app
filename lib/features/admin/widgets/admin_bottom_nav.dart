import 'package:flutter/material.dart';

/// Phone navigation: four destinations, a raised Create button in the middle
/// and a "More" entry for the rest. Page indexes match AdminDashboard:
/// 0 Overview, 1 Create Job, 2 Manage Jobs, 3 Candidates, 4 Analytics,
/// 5 Settings.
class AdminBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onMore;

  const AdminBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onMore,
  });

  static const Color blue = Color(0xFF4F6EF7);
  static const Color muted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE9EDF5))),
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
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view_rounded,
                  label: 'Overview',
                  selected: selectedIndex == 0,
                  onTap: () => onSelected(0),
                ),
                _item(
                  icon: Icons.work_outline,
                  activeIcon: Icons.work,
                  label: 'Jobs',
                  selected: selectedIndex == 2,
                  onTap: () => onSelected(2),
                ),
                _createButton(),
                _item(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Candidates',
                  selected: selectedIndex == 3,
                  onTap: () => onSelected(3),
                ),
                _item(
                  icon: Icons.more_horiz_rounded,
                  activeIcon: Icons.more_horiz_rounded,
                  label: 'More',
                  selected: selectedIndex >= 4,
                  onTap: onMore,
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
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? blue.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: 22,
                color: selected ? blue : muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? blue : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _createButton() {
    final selected = selectedIndex == 1;

    return Expanded(
      child: Center(
        child: Semantics(
          button: true,
          label: 'Create job',
          child: GestureDetector(
            onTap: () => onSelected(1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: selected
                      ? const [Color(0xFF3B57E6), Color(0xFF2D44C9)]
                      : const [Color(0xFF7B93FF), blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(17),
                boxShadow: [
                  BoxShadow(
                    color: blue.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
