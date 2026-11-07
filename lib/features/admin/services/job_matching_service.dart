import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';

String? _text(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

double _number(Object? value) => value is num ? value.toDouble() : 0;

List<String> _strings(Object? value) {
  if (value is! List) return <String>[];
  return value.map((item) => item.toString()).toList();
}

/// One candidate ranked for one job (a document of jobs/{id}/matches).
class CandidateMatch {
  CandidateMatch({
    required this.candidateId,
    required this.rank,
    required this.score,
    required this.eligibility,
    required this.breakdown,
    required this.mustHaveCoverage,
    required this.matchedSkills,
    required this.missingSkills,
    required this.relevantYears,
    required this.totalYears,
    required this.strengths,
    required this.gaps,
    required this.redFlags,
    required this.summary,
    required this.knockedOut,
    this.name,
    this.email,
    this.title,
    this.knockoutReason,
  });

  final String candidateId;
  final int rank;
  final double score;
  final String eligibility; // highly_eligible | potential | low_match
  final Map<String, double> breakdown;
  final double mustHaveCoverage;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final double relevantYears;
  final double totalYears;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> redFlags;
  final String summary;
  final bool knockedOut;
  final String? name;
  final String? email;
  final String? title;
  final String? knockoutReason;

  String get displayName => name ?? email ?? 'Candidate $candidateId';

  factory CandidateMatch.fromJson(Map<String, dynamic> json) {
    final scores = <String, double>{};
    final rawBreakdown = json['breakdown'];
    if (rawBreakdown is Map) {
      rawBreakdown.forEach((key, value) {
        if (value is num) scores[key.toString()] = value.toDouble();
      });
    }

    return CandidateMatch(
      candidateId: (json['candidate_id'] ?? '').toString(),
      rank: json['rank'] is num ? (json['rank'] as num).toInt() : 0,
      score: _number(json['overall_score']),
      eligibility: (json['eligibility'] ?? 'low_match').toString(),
      breakdown: scores,
      mustHaveCoverage: _number(json['must_have_coverage']),
      matchedSkills: _strings(json['matched_skills']),
      missingSkills: _strings(json['missing_skills']),
      relevantYears: _number(json['relevant_years']),
      totalYears: _number(json['total_years']),
      strengths: _strings(json['strengths']),
      gaps: _strings(json['gaps']),
      redFlags: _strings(json['red_flags']),
      summary: _text(json['summary']) ?? '',
      knockedOut: json['knocked_out'] == true,
      name: _text(json['candidate_name']),
      email: _text(json['candidate_email']),
      title: _text(json['candidate_title']),
      knockoutReason: _text(json['knockout_reason']),
    );
  }
}

/// The saved ranking of a job plus the status of the last matching run.
class JobMatchData {
  JobMatchData({
    required this.jobId,
    required this.status,
    required this.results,
    this.jobTitle,
    this.error,
    this.matchedAt,
    this.evaluated,
    this.skippedNoProfile,
  });

  final String jobId;
  final String status; // not_started | processing | completed | failed
  final List<CandidateMatch> results;
  final String? jobTitle;
  final String? error;
  final DateTime? matchedAt;
  final int? evaluated;
  final int? skippedNoProfile;

  bool get isRunning => status == 'processing';

  factory JobMatchData.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];
    final results = <CandidateMatch>[];
    if (rawResults is List) {
      for (final item in rawResults) {
        if (item is Map<String, dynamic>) {
          results.add(CandidateMatch.fromJson(item));
        }
      }
    }

    final matchedAt = json['matched_at'];

    return JobMatchData(
      jobId: (json['job_id'] ?? '').toString(),
      status: (json['match_status'] ?? 'not_started').toString(),
      results: results,
      jobTitle: _text(json['job_title']),
      error: _text(json['match_error']),
      matchedAt: matchedAt is String ? DateTime.tryParse(matchedAt) : null,
      evaluated: json['evaluated'] is num
          ? (json['evaluated'] as num).toInt()
          : null,
      skippedNoProfile: json['skipped_no_profile'] is num
          ? (json['skipped_no_profile'] as num).toInt()
          : null,
    );
  }
}

class ResumeLink {
  ResumeLink({required this.url, this.fileName});

  final String url;
  final String? fileName;
}

class JobMatchingService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<JobMatchData> fetchMatches(String jobId) async {
    final response = await _send('GET', ApiConfig.jobMatchesEndpoint(jobId));
    return JobMatchData.fromJson(_decode(response));
  }

  /// Starts matching in the background. If a run is already in progress the
  /// server answers 409, which is fine: the screen just keeps watching it.
  Future<void> startMatching(String jobId) async {
    final response = await _send('POST', ApiConfig.jobMatchEndpoint(jobId));
    if (response.statusCode == 409) return;
    _decode(response);
  }

  Future<ResumeLink> getResumeLink(String uid) async {
    final json = _decode(
      await _send('GET', ApiConfig.candidateResumeEndpoint(uid)),
    );

    final url = json['url'];
    if (url is! String || url.isEmpty) {
      throw StateError('The server did not return a resume link.');
    }

    return ResumeLink(url: url, fileName: _text(json['file_name']));
  }

  Future<http.Response> _send(String method, Uri uri) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Could not obtain a Firebase authentication token.');
    }

    final headers = {'Authorization': 'Bearer $token'};
    final Future<http.Response> request = method == 'POST'
        ? http.post(uri, headers: headers)
        : http.get(uri, headers: headers);

    return request.timeout(const Duration(seconds: 60));
  }

  Map<String, dynamic> _decode(http.Response response) {
    final Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw StateError(
        'The server returned an invalid response (HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode != 200) {
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw StateError(
        detail is String
            ? detail
            : 'Request failed (HTTP ${response.statusCode}).',
      );
    }

    if (body is! Map<String, dynamic>) {
      throw StateError('The server returned an invalid response.');
    }

    return body;
  }
}
