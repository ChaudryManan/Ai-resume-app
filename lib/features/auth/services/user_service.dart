
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user information from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    DocumentSnapshot<Map<String, dynamic>> document =
        await _firestore.collection('users').doc(uid).get();

    if (document.exists) {
      return document.data();
    }

    return null;
  }

  // Get the user's role
  Future<String?> getUserRole(String uid) async {
    Map<String, dynamic>? userData = await getUserData(uid);

    if (userData != null) {
      return userData['role'] as String?;
    }

    return null;
  }
}
