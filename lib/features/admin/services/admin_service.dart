
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save a new job in Firestore.
  Future<String> createJob({
    required String title,
    required String department,
    required String location,
    required String jobType,
    required String salary,
    required String description,
    required String responsibilities,
    required String education,
    required String experience,
    required String skills,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to create a job.');
    }

    final document = await _firestore.collection('jobs').add({
      'title': title.trim(),
      'department': department.trim(),
      'location': location.trim(),
      'jobType': jobType,
      'salary': salary.trim(),
      'description': description.trim(),
      'responsibilities': responsibilities.trim(),
      'education': education,
      'experience': experience,
      'skills': skills
          .split(',')
          .map((skill) => skill.trim())
          .where((skill) => skill.isNotEmpty)
          .toList(),
      'status': 'Active',
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  // Get all jobs as a real-time stream.
  Stream<QuerySnapshot<Map<String, dynamic>>> getJobs() {
    return _firestore
        .collection('jobs')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Update a job.
  Future<void> updateJob(
    String jobId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('jobs').doc(jobId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete a job.
  Future<void> deleteJob(String jobId) async {
    await _firestore.collection('jobs').doc(jobId).delete();
  }
}
