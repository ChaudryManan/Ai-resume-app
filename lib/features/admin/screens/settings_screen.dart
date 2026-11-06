
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

  Widget sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    IconData? icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE9EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: blue, size: 21),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: navy,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 22),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 19),
            filled: true,
            fillColor: readOnly
                ? const Color(0xFFF1F5F9)
                : const Color(0xFFFAFBFE),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ],
    );
  }

  Widget notificationTile({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: blue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172554),
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Manage your administrator account and preferences.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),

            // Admin profile
            sectionCard(
              title: 'Administrator Profile',
              subtitle: 'Update your personal account information.',
              icon: Icons.person_outline,
              child: Column(
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: const Color(0xFFEEF2FF),
                          child: Icon(
                            Icons.person,
                            size: 38,
                            color: blue,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          admin?.displayName ?? 'Administrator',
                          style: TextStyle(
                            color: navy,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Administrator Account',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 550) {
                        return Column(
                          children: [
                            inputField(
                              label: 'Full Name',
                              controller: nameController,
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 16),
                            inputField(
                              label: 'Email Address',
                              controller: emailController,
                              icon: Icons.email_outlined,
                              readOnly: true,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: inputField(
                              label: 'Full Name',
                              controller: nameController,
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: inputField(
                              label: 'Email Address',
                              controller: emailController,
                              icon: Icons.email_outlined,
                              readOnly: true,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Company information
            sectionCard(
              title: 'Company Information',
              subtitle: 'Add the organization details used by recruiters.',
              icon: Icons.business_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  inputField(
                    label: 'Company Name',
                    controller: companyController,
                    icon: Icons.business_outlined,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Company information is currently stored only in this form. '
                    'Firestore integration will be added later.',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Notifications
            sectionCard(
              title: 'Notification Preferences',
              subtitle: 'Choose which notifications you want to receive.',
              icon: Icons.notifications_none,
              child: Column(
                children: [
                  notificationTile(
                    title: 'Email Notifications',
                    description: 'Receive important updates through email.',
                    value: emailNotifications,
                    onChanged: (value) {
                      setState(() => emailNotifications = value);
                    },
                  ),
                  notificationTile(
                    title: 'New Applications',
                    description: 'Get notified when candidates apply for jobs.',
                    value: applicationNotifications,
                    onChanged: (value) {
                      setState(() => applicationNotifications = value);
                    },
                  ),
                  notificationTile(
                    title: 'Weekly Reports',
                    description: 'Receive weekly recruitment summaries.',
                    value: weeklyReports,
                    onChanged: (value) {
                      setState(() => weeklyReports = value);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Security
            sectionCard(
              title: 'Account Security',
              subtitle: 'Protect your administrator account.',
              icon: Icons.security_outlined,
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Password',
                          style: TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Receive an email with instructions to reset your password.',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: changePassword,
                    child: const Text('Reset Password'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Logout
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Sign out of your administrator account.',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: logout,
                    icon: const Icon(Icons.logout, size: 17),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC6262),
                      foregroundColor: Colors.white,
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
