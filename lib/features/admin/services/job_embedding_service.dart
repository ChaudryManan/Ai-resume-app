import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';

class JobEmbeddingService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Asks the backend to read the job from Firestore, embed it, and store
  /// the vectors in Supabase. Returns the number of chunks stored.
  Future<int> generateJobEmbeddings(String jobId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please log in before processing a job.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Could not obtain a Firebase authentication token.');
    }

    final response = await http
        .post(
          ApiConfig.jobEmbeddingEndpoint(jobId),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(minutes: 3));
        debugPrint('[JobEmbedding] POST ${ApiConfig.jobEmbeddingEndpoint(jobId)}');
        debugPrint('[JobEmbedding] HTTP ${response.statusCode}: ${response.body}');
    final Object? responseBody;
    try {
      responseBody = jsonDecode(response.body);
    } on FormatException {
      throw StateError(
        'Job processing service returned an invalid response '
        '(HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode != 200) {
      final detail = responseBody is Map<String, dynamic>
          ? responseBody['detail']
          : null;
      throw StateError(
        detail is String
            ? detail
            : 'Job processing failed (HTTP ${response.statusCode}).',
      );
    }

    if (responseBody is! Map<String, dynamic> ||
        responseBody['chunks_stored'] is! int) {
      throw StateError('Job processing service returned an invalid result.');
    }

    return responseBody['chunks_stored'] as int;
  }
}
