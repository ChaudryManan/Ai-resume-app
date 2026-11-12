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

int _int(Object? value) => value is num ? value.toInt() : 0;

List<String> _strings(Object? value) {
  if (value is! List) return <String>[];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

/// A readable error that can be shown to the candidate as is.
class InsightsException implements Exception {
  InsightsException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ----------------------------------------------------------------- profile

class ProfileEducation {
  ProfileEducation({this.degree, this.field, this.institution, this.year});

  final String? degree;
  final String? field;
  final String? institution;
  final String? year;

  factory ProfileEducation.fromJson(Map<String, dynamic> json) {
    return ProfileEducation(
      degree: _text(json['degree']),
      field: _text(json['field_of_study']),
      institution: _text(json['institution']),
      year: _text(json['graduation_year']),
    );
  }

  /// "BSc Computer Science"
  String get title {
    final parts = [degree, field].whereType<String>().toList();
    return parts.isEmpty ? (institution ?? 'Education') : parts.join(' · ');
  }
}

class ProfileWork {
  ProfileWork({this.company, this.title, this.duration});

  final String? company;
  final String? title;
  final String? duration;

  factory ProfileWork.fromJson(Map<String, dynamic> json) {
    return ProfileWork(
      company: _text(json['company']),
      title: _text(json['job_title']),
      duration: _text(json['duration']),
    );
  }
}

/// What the AI extracted from the candidate's resume.
class CandidateProfileData {
  CandidateProfileData({
    required this.skills,
    required this.education,
    required this.work,
    required this.certifications,
    required this.projects,
    required this.languages,
    this.fullName,
    this.title,
    this.email,
    this.phone,
    this.location,
    this.summary,
    this.totalExperience,
  });

  final String? fullName;
  final String? title;
  final String? email;
  final String? phone;
  final String? location;
  final String? summary;
  final String? totalExperience;
  final List<String> skills;
  final List<ProfileEducation> education;
  final List<ProfileWork> work;
  final List<String> certifications;
  final List<String> projects;
  final List<String> languages;

  factory CandidateProfileData.fromJson(Map<String, dynamic> json) {
    List<T> items<T>(Object? raw, T Function(Map<String, dynamic>) build) {
      if (raw is! List) return <T>[];
      return raw.whereType<Map>().map((e) => build(_map(e))).toList();
    }

    return CandidateProfileData(
      fullName: _text(json['full_name']),
      title: _text(json['professional_title']),
      email: _text(json['email']),
      phone: _text(json['phone']),
      location: _text(json['location']),
      summary: _text(json['professional_summary']),
      totalExperience: _text(json['total_experience']),
      skills: _strings(json['technical_skills']),
      education: items(json['education'], ProfileEducation.fromJson),
      work: items(json['work_experience'], ProfileWork.fromJson),
      certifications: _strings(json['certifications']),
      projects: _strings(json['projects']),
      languages: _strings(json['languages']),
    );
  }
}

// ----------------------------------------------------------------- matches

/// How this candidate's resume scored for one job.
class MyJobMatch {
  MyJobMatch({
    required this.jobId,
    required this.jobTitle,
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
    required this.summary,
    this.department,
    this.location,
    this.jobType,
    this.scoredAt,
  });

  final String jobId;
  final String jobTitle;
  final String? department;
  final String? location;
  final String? jobType;
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
  final String summary;
  final DateTime? scoredAt;

  factory MyJobMatch.fromJson(Map<String, dynamic> json) {
    final breakdown = <String, double>{};
    _map(json['breakdown']).forEach((key, value) {
      if (value is num) breakdown[key] = value.toDouble();
    });

    final scoredAt = json['scored_at'];

    return MyJobMatch(
      jobId: (json['job_id'] ?? '').toString(),
      jobTitle: _text(json['job_title']) ?? 'Untitled job',
      department: _text(json['department']),
      location: _text(json['location']),
      jobType: _text(json['job_type']),
      score: _number(json['score']),
      eligibility: (json['eligibility'] ?? 'low_match').toString(),
      breakdown: breakdown,
      mustHaveCoverage: _number(json['must_have_coverage']),
      matchedSkills: _strings(json['matched_skills']),
      missingSkills: _strings(json['missing_skills']),
      relevantYears: _number(json['relevant_years']),
      totalYears: _number(json['total_years']),
      strengths: _strings(json['strengths']),
      gaps: _strings(json['gaps']),
      summary: _text(json['summary']) ?? '',
      scoredAt: scoredAt is String ? DateTime.tryParse(scoredAt) : null,
    );
  }
}

class SkillCount {
  const SkillCount(this.skill, this.count);

  final String skill;
  final int count;
}

class InsightsSummary {
  const InsightsSummary({
    required this.highlyEligible,
    required this.potential,
    required this.lowMatch,
    this.averageScore,
    this.bestScore,
  });

  final int highlyEligible;
  final int potential;
  final int lowMatch;
  final double? averageScore;
  final double? bestScore;

  int get total => highlyEligible + potential + lowMatch;
}

class CandidateInsights {
  CandidateInsights({
    required this.summary,
    required this.matches,
    required this.topSkills,
    required this.skillGaps,
    required this.jobsTotal,
    required this.jobsEvaluated,
    required this.highlyEligibleMin,
    required this.potentialMin,
    this.profile,
  });

  final CandidateProfileData? profile;
  final InsightsSummary summary;
  final List<MyJobMatch> matches; // best score first
  final List<SkillCount> topSkills;
  final List<SkillCount> skillGaps;
  final int jobsTotal;
  final int jobsEvaluated;
  final int highlyEligibleMin;
  final int potentialMin;

  bool get hasProfile => profile != null;

  /// Jobs where the resume is at least a high-potential match.
  int get matchedJobs => summary.highlyEligible + summary.potential;

  int get notEvaluated {
    final difference = jobsTotal - jobsEvaluated;
    return difference < 0 ? 0 : difference;
  }

  MyJobMatch? matchFor(String jobId) {
    for (final match in matches) {
      if (match.jobId == jobId) return match;
    }
    return null;
  }

  factory CandidateInsights.fromJson(Map<String, dynamic> json) {
    List<SkillCount> skills(Object? raw) {
      if (raw is! List) return <SkillCount>[];
      return raw.whereType<Map>().map((item) {
        final data = _map(item);
        return SkillCount((data['skill'] ?? '').toString(), _int(data['count']));
      }).toList();
    }

    final rawProfile = json['profile'];
    final summary = _map(json['summary']);
    final thresholds = _map(json['thresholds']);

    final matches = <MyJobMatch>[];
    final rawMatches = json['matches'];
    if (rawMatches is List) {
      for (final item in rawMatches) {
        if (item is Map) matches.add(MyJobMatch.fromJson(_map(item)));
      }
    }

    return CandidateInsights(
      profile: rawProfile is Map
          ? CandidateProfileData.fromJson(_map(rawProfile))
          : null,
      summary: InsightsSummary(
        highlyEligible: _int(summary['highly_eligible']),
        potential: _int(summary['potential']),
        lowMatch: _int(summary['low_match']),
        averageScore: summary['average_score'] is num
            ? (summary['average_score'] as num).toDouble()
            : null,
        bestScore: summary['best_score'] is num
            ? (summary['best_score'] as num).toDouble()
            : null,
      ),
      matches: matches,
      topSkills: skills(json['top_skills']),
      skillGaps: skills(json['skill_gaps']),
      jobsTotal: _int(json['jobs_total']),
      jobsEvaluated: _int(json['jobs_evaluated']),
      highlyEligibleMin: thresholds['highly_eligible'] is num
          ? (thresholds['highly_eligible'] as num).toInt()
          : 75,
      potentialMin: thresholds['potential'] is num
          ? (thresholds['potential'] as num).toInt()
          : 60,
    );
  }
}

// ----------------------------------------------------------------- service

class UserInsightsService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<CandidateInsights> fetch() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw InsightsException('Please log in again.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw InsightsException('Could not verify your login. Please log in again.');
    }

    final Uri uri;
    try {
      uri = ApiConfig.myInsightsEndpoint;
    } on StateError catch (error) {
      throw InsightsException(error.message);
    }

    final http.Response response;
    try {
      response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw InsightsException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw InsightsException(
        'Could not reach the server. Check your connection and make sure '
        'the backend is running.',
      );
    }

    final Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw InsightsException(
        'The server returned an invalid response (HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode != 200) {
      final detail = body is Map<String, dynamic> ? body['detail'] : null;

      if (response.statusCode == 404 && detail == 'Not Found') {
        throw InsightsException(
          'Insights are not available yet. Update and restart the backend.',
        );
      }

      throw InsightsException(
        detail is String
            ? detail
            : 'Could not load your insights (HTTP ${response.statusCode}).',
      );
    }

    if (body is! Map<String, dynamic>) {
      throw InsightsException('The server returned an invalid response.');
    }

    return CandidateInsights.fromJson(body);
  }
}
