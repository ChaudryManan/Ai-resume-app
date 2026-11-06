
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/services/user_service.dart';
import '../../features/admin/screens/admin_dashboard.dart';
import '../../features/user/screens/user_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // Check whether Firebase is loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is not logged in
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // If user is logged in, check their role
        final user = snapshot.data!;

        return FutureBuilder<String?>(
          future: UserService().getUserRole(user.uid),
          builder: (context, roleSnapshot) {

            if (roleSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (roleSnapshot.hasError) {
              return const Scaffold(
                body: Center(
                  child: Text('Unable to load your account.'),
                ),
              );
            }

            final role = roleSnapshot.data;

            if (role == 'admin') {
              return const AdminDashboard();
            }

            if (role == 'user') {
              return const UserDashboard();
            }

            return const Scaffold(
              body: Center(
                child: Text('Account role not found. Contact administrator.'),
              ),
            );
          },
        );
      },
    );
  }
}
