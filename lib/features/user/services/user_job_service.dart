import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserJobService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get active jobs.
  Stream<QuerySnapshot<Map<String, dynamic>>> getJobs() {
    return _firestore
        .collection('jobs')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get applications of the currently logged-in user.
  Stream<QuerySnapshot<Map<String, dynamic>>> getMyApplications() {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    return _firestore
        .collection('applications')
        .where('uid', isEqualTo: user.uid)
        .snapshots();
  }

  // Get the currently logged-in user's resume.
  Stream<DocumentSnapshot<Map<String, dynamic>>> getMyResume() {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    return _firestore.collection('resumes').doc(user.uid).snapshots();
  }

  // Upload a new resume or replace the existing one.
  Future<void> uploadOrReplaceResume({
    required Uint8List resumeBytes,
    required String resumeFileName,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    if (resumeBytes.isEmpty) {
      throw Exception('The selected file is empty.');
    }

    if (resumeBytes.length > 5 * 1024 * 1024) {
      throw Exception('Resume must not exceed 5 MB.');
    }

    final resumeRef = _firestore.collection('resumes').doc(user.uid);

    // Read the previous resume information.
    final oldResumeSnapshot = await resumeRef.get();
    final oldResumeData = oldResumeSnapshot.data();
    final oldResumePath = oldResumeData?['storagePath'] as String?;

    // Create a safe file name.
    final safeFileName = resumeFileName.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );

    // Each upload gets a unique path.
    final newResumePath =
        '${user.uid}/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

    final storage = Supabase.instance.client.storage.from('resumes');

    // Upload the new PDF first.
    await storage.uploadBinary(
      newResumePath,
      resumeBytes,
      fileOptions: const FileOptions(
        contentType: 'application/pdf',
        upsert: false,
      ),
    );

    try {
      // Save the new resume information in Firestore.
      await resumeRef.set({
        'uid': user.uid,
        'fileName': resumeFileName,
        'storagePath': newResumePath,
        'bucket': 'resumes',
        'embeddingStatus': 'pending',
        'uploadedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // If Firestore saving fails, remove the newly uploaded file.
      try {
        await storage.remove([newResumePath]);
      } catch (deleteError) {
        print('Could not clean up new resume: $deleteError');
      }

      rethrow;
    }

    // After the new resume is saved, delete the old file.
    if (oldResumePath != null &&
        oldResumePath.isNotEmpty &&
        oldResumePath != newResumePath) {
      try {
        await storage.remove([oldResumePath]);
      } catch (e) {
        // The new resume is already saved, so an old-file
        // deletion failure should not undo the successful upload.
        print('Could not delete previous resume: $e');
      }
    }
  }

  // Apply for a job using the candidate's existing resume.
  Future<void> applyForJob({
    required String jobId,
    required String jobTitle,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please login first.');
    }

    // Check whether the candidate has uploaded a resume.
    final resumeSnapshot = await _firestore
        .collection('resumes')
        .doc(user.uid)
        .get();

    if (!resumeSnapshot.exists) {
      throw Exception('Please upload your resume before applying.');
    }

    final resumeData = resumeSnapshot.data();

    if (resumeData == null || resumeData['storagePath'] == null) {
      throw Exception(
        'Your resume record is incomplete. Please upload it again.',
      );
    }

    final applicationId = '${user.uid}_$jobId';

    final applicationRef = _firestore
        .collection('applications')
        .doc(applicationId);

    await _firestore.runTransaction((transaction) async {
      final existingApplication = await transaction.get(applicationRef);

      if (existingApplication.exists) {
        throw Exception('You have already applied for this job.');
      }

      transaction.set(applicationRef, {
        'uid': user.uid,
        'userName': user.displayName ?? '',
        'email': user.email ?? '',
        'jobId': jobId,
        'jobTitle': jobTitle,
        'status': 'Pending',
        'resumeFileName': resumeData['fileName'],
        'resumePath': resumeData['storagePath'],
        'resumeBucket': 'resumes',
        'appliedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
