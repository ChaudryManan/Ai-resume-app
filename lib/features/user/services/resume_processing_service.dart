import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';

class ResumeProcessingService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Step 1: Gemini reads the uploaded PDF and saves the candidate profile.
  /// Step 2: the profile is embedded and stored in Supabase.
  /// Returns the number of embedded sections.
  Future<int> processResume() async {
    final token = await _getToken();

    await _post(ApiConfig.resumeScreenEndpoint, token);
    final result = await _post(ApiConfig.resumeEmbeddingEndpoint, token);

    final chunksStored = result['chunks_stored'];
    if (chunksStored is! int) {
      throw StateError('Resume processing service returned an invalid result.');
    }

    return chunksStored;
  }

  Future<String> _getToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please log in before processing a resume.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Could not obtain a Firebase authentication token.');
    }

    return token;
  }

  Future<Map<String, dynamic>> _post(Uri uri, String token) async {
    final response = await http
        .post(uri, headers: {'Authorization': 'Bearer $token'})
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

    if (responseBody is! Map<String, dynamic>) {
      throw StateError('Resume processing service returned an invalid result.');
    }

    return responseBody;
  }
}
