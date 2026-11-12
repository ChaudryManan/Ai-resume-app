import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color navy = Color(0xFF172554);
  static const Color blue = Color(0xFF4F6EF7);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0xFFE9EDF5);

  final User? admin = FirebaseAuth.instance.currentUser;
  final nameController = TextEditingController();
  final companyController = TextEditingController();
  final emailController = TextEditingController();

  bool isSaving = false;
  bool isLoading = true;
  bool isUploadingPhoto = false;
  String? profileImageUrl;
  bool emailNotifications = true;
  bool applicationNotifications = true;
  bool weeklyReports = false;

  @override
  void initState() {
    super.initState();
    nameController.text = admin?.displayName ?? '';
    emailController.text = admin?.email ?? '';
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = admin;
    if (user == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      if (!mounted) return;
      setState(() {
        companyController.text = (data['companyName'] ?? '').toString();
        profileImageUrl = (data['profileImageUrl'] ?? user.photoURL)?.toString();
        emailNotifications = data['emailNotifications'] is bool ? data['emailNotifications'] as bool : true;
        applicationNotifications = data['applicationNotifications'] is bool ? data['applicationNotifications'] as bool : true;
        weeklyReports = data['weeklyReports'] is bool ? data['weeklyReports'] as bool : false;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showMessage('Could not load saved settings: $e');
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    companyController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _chooseProfilePicture() async {
  final user = admin;

  if (user == null) {
    _showMessage('Please sign in again.');
    return;
  }

  try {
    // Select one image using File Picker 13
    final file = await FilePicker.pickFile(
      type: FileType.image,
    );

    // User cancelled the picker
    if (file == null) return;

    // Read image bytes
    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      _showMessage('Could not read the selected image.');
      return;
    }

    // Maximum image size: 5 MB
    if (bytes.length > 5 * 1024 * 1024) {
      _showMessage('Please select an image smaller than 5 MB.');
      return;
    }

    if (!mounted) return;

    setState(() => isUploadingPhoto = true);

    final extension = (file.extension ?? 'jpg').toLowerCase();

    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };

    // Upload image to Firebase Storage
    final ref = FirebaseStorage.instance
        .ref()
        .child('admin_profiles/${user.uid}/profile.$extension');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );

    // Get uploaded image URL
    final url = await ref.getDownloadURL();

    // Save URL in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'uid': user.uid,
      'profileImageUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update Firebase Auth profile
    await user.updatePhotoURL(url);

    if (!mounted) return;

    setState(() {
      profileImageUrl = url;
      isUploadingPhoto = false;
    });

    _showMessage('Profile picture updated successfully.');
  } catch (e) {
    if (!mounted) return;

    setState(() => isUploadingPhoto = false);

    _showMessage('Failed to upload profile picture: $e');
  }
}

  Future<void> saveProfile() async {
    final user = admin;
    if (user == null) {
      _showMessage('Please sign in again.');
      return;
    }
    if (nameController.text.trim().isEmpty) {
      _showMessage('Please enter your name.');
      return;
    }
    if (companyController.text.trim().isEmpty) {
      _showMessage('Please enter your company name.');
      return;
    }

    setState(() => isSaving = true);
    try {
      await user.updateDisplayName(nameController.text.trim());
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': nameController.text.trim(),
        'email': user.email,
        'companyName': companyController.text.trim(),
        'profileImageUrl': profileImageUrl,
        'emailNotifications': emailNotifications,
        'applicationNotifications': applicationNotifications,
        'weeklyReports': weeklyReports,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await user.reload();
      if (!mounted) return;
      setState(() => isSaving = false);
      _showMessage('Company and profile settings saved.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      _showMessage(e.message ?? 'Unable to update profile.');
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      _showMessage('Unable to save settings: $e');
    }
  }

  Future<void> changePassword() async {
    final email = admin?.email;
    if (email == null || email.isEmpty) {
      _showMessage('No account email found.');
      return;
    }
    try {
      await AuthService().resetPassword(email);
      if (mounted) _showMessage('Password reset email sent to $email.');
    } on FirebaseAuthException catch (e) {
      if (mounted) _showMessage(e.message ?? 'Unable to send reset email.');
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to manage jobs and candidates.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC6262)),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await AuthService().logout();
  }

  Widget _card(String title, String subtitle, Widget child, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: blue),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 18),
        child,
      ]),
    );
  }

  Widget _field(String label, TextEditingController controller, IconData icon, {bool readOnly = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        readOnly: readOnly,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFFAFBFE),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
    ]);
  }

  Widget _notification(String title, String description, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600)),
      subtitle: Text(description, style: const TextStyle(color: muted, fontSize: 12)),
      value: value,
      activeThumbColor: blue,
      onChanged: (next) => setState(() => onChanged(next)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final name = nameController.text.trim();
    return Container(
      color: const Color(0xFFF5F7FC),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(compact ? 16 : 25),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Settings', style: TextStyle(fontSize: compact ? 24 : 27, fontWeight: FontWeight.w800, color: navy)),
                    const SizedBox(height: 6),
                    const Text('Manage your administrator account and company profile.', style: TextStyle(color: muted, fontSize: 13)),
                    const SizedBox(height: 22),
                    _card('Administrator Profile', 'Update your name and profile picture.', Column(children: [
                      Center(child: Column(children: [
                        Stack(alignment: Alignment.bottomRight, children: [
                          CircleAvatar(
                            radius: 43,
                            backgroundColor: const Color(0xFFEEF2FF),
                            backgroundImage: profileImageUrl == null || profileImageUrl!.isEmpty ? null : NetworkImage(profileImageUrl!),
                            child: profileImageUrl == null || profileImageUrl!.isEmpty
                                ? Text(name.isEmpty ? 'A' : name[0].toUpperCase(), style: const TextStyle(color: blue, fontSize: 30, fontWeight: FontWeight.w800))
                                : null,
                          ),
                          Material(
                            color: blue,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: isUploadingPhoto ? null : _chooseProfilePicture,
                              child: Padding(
                                padding: const EdgeInsets.all(9),
                                child: isUploadingPhoto
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 17),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text(isUploadingPhoto ? 'Uploading picture...' : 'Change profile picture', style: const TextStyle(color: muted, fontSize: 12)),
                      ])),
                      const SizedBox(height: 20),
                      _field('Full Name', nameController, Icons.person_outline),
                      const SizedBox(height: 14),
                      _field('Email Address', emailController, Icons.email_outlined, readOnly: true),
                    ]), Icons.person_outline),
                    const SizedBox(height: 16),
                    _card('Company Information', 'This company name is saved to your administrator profile.', Column(children: [
                      _field('Company Name', companyController, Icons.business_outlined),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: compact ? double.infinity : 190,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: isSaving ? null : saveProfile,
                          icon: isSaving
                              ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_outlined, size: 18),
                          label: const Text('Save Changes'),
                          style: FilledButton.styleFrom(backgroundColor: blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ]), Icons.business_outlined),
                    const SizedBox(height: 16),
                    _card('Notification Preferences', 'Choose which notifications you want to receive.', Column(children: [
                      _notification('Email Notifications', 'Receive important updates through email.', emailNotifications, (v) => emailNotifications = v),
                      _notification('New Applications', 'Get notified when candidates apply for jobs.', applicationNotifications, (v) => applicationNotifications = v),
                      _notification('Weekly Reports', 'Receive weekly recruitment summaries.', weeklyReports, (v) => weeklyReports = v),
                      Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: isSaving ? null : saveProfile, icon: const Icon(Icons.save_outlined), label: const Text('Save Preferences'))),
                    ]), Icons.notifications_none),
                    const SizedBox(height: 16),
                    _card('Account Security', 'Protect your administrator account.', Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(onPressed: changePassword, icon: const Icon(Icons.lock_reset_rounded), label: const Text('Send Password Reset Email')),
                    ), Icons.security_outlined),
                    const SizedBox(height: 16),
                    _card('Sign Out', 'Sign out of your administrator account.', Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _confirmLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC6262)),
                      ),
                    ), Icons.logout),
                  ]),
                ),
              ),
            ),
    );
  }
}
