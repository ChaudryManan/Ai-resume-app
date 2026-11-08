
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final User? admin = FirebaseAuth.instance.currentUser;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController companyController =
      TextEditingController();
  final TextEditingController emailController = TextEditingController();

  bool emailNotifications = true;
  bool applicationNotifications = true;
  bool weeklyReports = false;

  bool isSaving = false;

  final Color navy = const Color(0xFF172554);
  final Color blue = const Color(0xFF4F6EF7);

  @override
  void initState() {
    super.initState();

    nameController.text = admin?.displayName ?? '';
    emailController.text = admin?.email ?? '';
  }

  @override
  void dispose() {
    nameController.dispose();
    companyController.dispose();
    emailController.dispose();
    super.dispose();
  }

  static const Color _muted = Color(0xFF64748B);
  static const Color _faint = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE9EDF5);

  // ------------------------------------------------------------- widgets

  Widget sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    IconData? icon,
    required bool compact,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A172554),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: blue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: blue, size: 19),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.4),
          ),
          SizedBox(height: compact ? 18 : 22),
          child,
        ],
      ),
    );
  }

  Widget inputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          style: TextStyle(
            fontSize: 15,
            color: readOnly ? _muted : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: readOnly
                ? const Color(0xFFF1F5F9)
                : const Color(0xFFFAFBFE),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: blue, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  /// The whole row is tappable (not just the small switch).
  Widget notificationTile({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool last = false,
  }) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: const TextStyle(
                          color: _faint,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: value,
                  activeThumbColor: blue,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
        if (!last) const Divider(height: 1, color: Color(0xFFF1F4F9)),
      ],
    );
  }

  /// Text on the left and one button on the right on wide screens.
  /// On phones the button drops under the text and fills the width.
  Widget actionRow({
    required bool compact,
    required String title,
    required String description,
    required Color titleColor,
    required Widget button,
  }) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          text,
          const SizedBox(height: 14),
          button,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: text),
        const SizedBox(width: 16),
        button,
      ],
    );
  }

  Widget _header(bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: TextStyle(
            fontSize: compact ? 24 : 27,
            fontWeight: FontWeight.w800,
            color: navy,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Manage your administrator account and preferences.',
          style: TextStyle(fontSize: 13, color: _muted, height: 1.4),
        ),
      ],
    );
  }

  Widget _profileHeader() {
    final name = (admin?.displayName ?? '').trim();
    final shown = name.isEmpty ? 'Administrator' : name;

    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: const Color(0xFFEEF2FF),
            child: name.isEmpty
                ? Icon(Icons.person, size: 38, color: blue)
                : Text(
                    name[0].toUpperCase(),
                    style: TextStyle(
                      color: blue,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            shown,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: navy,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Administrator Account',
            style: TextStyle(color: _faint, fontSize: 12),
          ),
        ],
      ),
    );
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

  Future<void> saveProfile() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name.')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      await admin?.updateDisplayName(nameController.text.trim());
      await admin?.reload();

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() => isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Unable to update profile.')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
    }
  }

  Future<void> changePassword() async {
    final email = admin?.email;

    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No account email found.')),
      );
      return;
    }

    try {
      await AuthService().resetPassword(email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Unable to send reset email.')),
      );
    }
  }

  Future<void> logout() async {
    await AuthService().logout();
  }


  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FC),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final padding = compact ? 16.0 : 25.0;
          final gap = compact ? 14.0 : 18.0;
          final sideBySide = constraints.maxWidth - padding * 2 >= 550;

          final saveButton = ElevatedButton.icon(
            onPressed: isSaving ? null : saveProfile,
            icon: isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: blue,
              foregroundColor: Colors.white,
              minimumSize: Size(compact ? double.infinity : 0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          final resetButton = OutlinedButton.icon(
            onPressed: changePassword,
            icon: const Icon(Icons.lock_reset_rounded, size: 18),
            label: const Text('Reset Password'),
            style: OutlinedButton.styleFrom(
              foregroundColor: blue,
              side: BorderSide(color: blue.withValues(alpha: 0.4)),
              minimumSize: Size(compact ? double.infinity : 0, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          final logoutButton = ElevatedButton.icon(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC6262),
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: Size(compact ? double.infinity : 0, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          final nameField = inputField(
            label: 'Full Name',
            controller: nameController,
            icon: Icons.person_outline,
            textInputAction: TextInputAction.done,
          );

          final emailField = inputField(
            label: 'Email Address',
            controller: emailController,
            icon: Icons.email_outlined,
            readOnly: true,
            keyboardType: TextInputType.emailAddress,
          );

          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.all(padding),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(compact),
                    SizedBox(height: compact ? 18 : 24),

                    // Admin profile
                    sectionCard(
                      title: 'Administrator Profile',
                      subtitle: 'Update your personal account information.',
                      icon: Icons.person_outline,
                      compact: compact,
                      child: Column(
                        children: [
                          _profileHeader(),
                          SizedBox(height: compact ? 20 : 25),
                          if (sideBySide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: nameField),
                                const SizedBox(width: 16),
                                Expanded(child: emailField),
                              ],
                            )
                          else
                            Column(
                              children: [
                                nameField,
                                const SizedBox(height: 16),
                                emailField,
                              ],
                            ),
                          const SizedBox(height: 20),
                          Align(
                            alignment:
                                compact ? Alignment.center : Alignment.centerRight,
                            child: saveButton,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: gap),

                    // Company information
                    sectionCard(
                      title: 'Company Information',
                      subtitle: 'Add the organization details used by recruiters.',
                      icon: Icons.business_outlined,
                      compact: compact,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          inputField(
                            label: 'Company Name',
                            controller: companyController,
                            icon: Icons.business_outlined,
                            textInputAction: TextInputAction.done,
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: _faint,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Company information is currently stored '
                                    'only in this form. Firestore integration '
                                    'will be added later.',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: gap),

                    // Notifications
                    sectionCard(
                      title: 'Notification Preferences',
                      subtitle: 'Choose which notifications you want to receive.',
                      icon: Icons.notifications_none,
                      compact: compact,
                      child: Column(
                        children: [
                          notificationTile(
                            title: 'Email Notifications',
                            description:
                                'Receive important updates through email.',
                            value: emailNotifications,
                            onChanged: (value) {
                              setState(() => emailNotifications = value);
                            },
                          ),
                          notificationTile(
                            title: 'New Applications',
                            description:
                                'Get notified when candidates apply for jobs.',
                            value: applicationNotifications,
                            onChanged: (value) {
                              setState(() => applicationNotifications = value);
                            },
                          ),
                          notificationTile(
                            title: 'Weekly Reports',
                            description: 'Receive weekly recruitment summaries.',
                            value: weeklyReports,
                            last: true,
                            onChanged: (value) {
                              setState(() => weeklyReports = value);
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: gap),

                    // Security
                    sectionCard(
                      title: 'Account Security',
                      subtitle: 'Protect your administrator account.',
                      icon: Icons.security_outlined,
                      compact: compact,
                      child: actionRow(
                        compact: compact,
                        title: 'Change Password',
                        description:
                            'Receive an email with instructions to reset your password.',
                        titleColor: const Color(0xFF334155),
                        button: resetButton,
                      ),
                    ),

                    SizedBox(height: gap),

                    // Logout
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(compact ? 16 : 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: actionRow(
                        compact: compact,
                        title: 'Sign Out',
                        description: 'Sign out of your administrator account.',
                        titleColor: const Color(0xFF991B1B),
                        button: logoutButton,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
