
import 'package:flutter/material.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  /// Icon-only rail for tablets.
  final bool compact;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.compact = false,
  });

  static const Color navy = Color(0xFF172554);
  static const Color selectedColor = Color(0xFF293B70);
  static const Color mutedColor = Color(0xFFB7C4E3);

  final List<IconData> icons = const [
    Icons.grid_view_rounded,
    Icons.add_box_outlined,
    Icons.work_outline,
    Icons.people_outline,
    Icons.analytics_outlined,
    Icons.settings_outlined,
  ];

  final List<String> labels = const [
    'Overview',
    'Create Job',
    'Manage Jobs',
    'Candidates',
    'Analytics',
    'Settings',
  ];

  Widget _buildCompact() {
    return Container(
      width: 78,
      height: double.infinity,
      color: navy,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 24),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 34),
            child: Icon(Icons.work_outline, color: Color(0xFF8FA5FF), size: 30),
          ),
          ...List.generate(labels.length, (index) {
            final isSelected = selectedIndex == index;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Tooltip(
                message: labels[index],
                child: Material(
                  color: isSelected ? selectedColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onItemSelected(index),
                    child: SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: Icon(
                        icons[index],
                        size: 22,
                        color: isSelected ? Colors.white : mutedColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          const Divider(color: Color(0xFF35456E)),
          Tooltip(
            message: 'Logout',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onItemSelected(6),
              child: const SizedBox(
                height: 50,
                width: double.infinity,
                child: Icon(Icons.logout, color: Color(0xFFFFA3A3), size: 21),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact();

    return Container(
      width: 235,
      height: double.infinity,
      color: navy,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 42),
            child: Row(
              children: [
                Icon(
                  Icons.work_outline,
                  color: Color(0xFF8FA5FF),
                  size: 29,
                ),
                SizedBox(width: 10),
                Text(
                  'HireFlow',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(left: 10, bottom: 15),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                color: Color(0xFF8293B8),
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          ...List.generate(labels.length, (index) {
            final isSelected = selectedIndex == index;

            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Material(
                color: isSelected ? selectedColor : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => onItemSelected(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icons[index],
                          size: 19,
                          color: isSelected ? Colors.white : mutedColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          labels[index],
                          style: TextStyle(
                            color: isSelected ? Colors.white : mutedColor,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          const Spacer(),
          const Divider(color: Color(0xFF35456E)),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => onItemSelected(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Color(0xFFFFA3A3), size: 19),
                    SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: Color(0xFFFFA3A3),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
