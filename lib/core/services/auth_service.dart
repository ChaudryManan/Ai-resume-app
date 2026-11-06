
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // SIGN UP
  Future<User?> signup(
    String name,
    String email,
    String password,
  ) async {
    UserCredential credential =
        await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    User? user = credential.user;

    if (user != null) {
      try {
        // Save user's name in Firebase Authentication
        await user.updateDisplayName(name.trim());

        // Create user's profile in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name.trim(),
          'email': email.trim(),
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Roll back account creation if profile creation fails
        try {
          await user.delete();
        } catch (_) {}

        rethrow;
      }
    }

    return user;
  }

  // LOGIN
  Future<User?> login(String email, String password) async {
    UserCredential credential =
        await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    return credential.user;
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }

  // GET CURRENT USER
  User? get currentUser {
    return _auth.currentUser;
  }

  // LISTEN TO LOGIN/LOGOUT CHANGES
  Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  // RESET PASSWORD
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }
}
