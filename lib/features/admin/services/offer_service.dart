import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';

class GeneratedOffer {
  const GeneratedOffer({required this.id, required this.candidateName, required this.candidateEmail, required this.subject, required this.body});
  final String id;
  final String candidateName;
  final String candidateEmail;
  final String subject;
  final String body;
  factory GeneratedOffer.fromJson(Map<String, dynamic> json) => GeneratedOffer(
    id: (json['offer_id'] ?? '').toString(),
    candidateName: (json['candidate_name'] ?? 'Candidate').toString(),
    candidateEmail: (json['candidate_email'] ?? '').toString(),
    subject: (json['subject'] ?? '').toString(),
    body: (json['body'] ?? '').toString(),
  );
}

class OfferService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Future<GeneratedOffer> generate({required String candidateId, required String jobId, required String salary, required List<String> benefits, String? workingHours, String? joiningDate, String? additionalTerms}) async {
    final data = await _request(ApiConfig.generateOfferEndpoint, {
      'candidate_id': candidateId, 'job_id': jobId, 'salary': salary,
      'benefits': benefits, 'working_hours': workingHours,
      'joining_date': joiningDate, 'additional_terms': additionalTerms,
    });
    return GeneratedOffer.fromJson(data);
  }
  Future<void> approveAndSend(String offerId) async {
    await _request(ApiConfig.sendOfferEndpoint(offerId), const {});
  }
  Future<Map<String, dynamic>> _request(Uri uri, Map<String, dynamic> body) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please log in again.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) throw StateError('Could not obtain a Firebase authentication token.');
    final response = await http.post(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(const Duration(seconds: 90));
    Object? decoded;
    try { decoded = jsonDecode(response.body); } on FormatException { throw StateError('Server returned an invalid response (${response.statusCode}).'); }
    if (response.statusCode != 200) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw StateError(detail is String ? detail : 'Request failed (${response.statusCode}).');
    }
    if (decoded is! Map<String, dynamic>) throw StateError('Server returned an invalid response.');
    return decoded;
  }
}