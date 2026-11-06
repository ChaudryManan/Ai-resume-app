import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';

class ResumeProcessingService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<int> generateResumeEmbeddings() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please log in before processing a resume.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Could not obtain a Firebase authentication token.');
    }

    final response = await http
        .post(
          ApiConfig.resumeEmbeddingEndpoint,
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(minutes: 3));

    final Object? responseBody;
    try {
      responseBody = jsonDecode(response.body);
    } on FormatException {
      throw StateError(
        'Resume processing service returned an invalid response '
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
            : 'Resume processing failed (HTTP ${response.statusCode}).',
      );
    }

    if (responseBody is! Map<String, dynamic> ||
        responseBody['chunks_stored'] is! int) {
      throw StateError('Resume processing service returned an invalid result.');
    }

    return responseBody['chunks_stored'] as int;
  }
}
