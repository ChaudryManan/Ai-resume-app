import 'package:flutter/foundation.dart';

class ApiConfig {
  // Optional override: --dart-define=API_BASE_URL=<backend-url>
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Backend address.
  ///
  /// 1. If API_BASE_URL is passed, that wins (use it for a phone or server).
  /// 2. In debug/profile runs it defaults to the local backend, so a plain
  ///    `flutter run -d chrome` works:
  ///      - web / desktop / iOS simulator -> http://localhost:8000
  ///      - Android emulator              -> http://10.0.2.2:8000
  /// 3. Release builds never fall back to localhost: pass API_BASE_URL.
  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    if (kReleaseMode) return '';

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://localhost:8000';
  }

  static Uri _resolve(String path) {
    if (baseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is not configured. Release builds need '
        '--dart-define=API_BASE_URL=<backend-url>.',
      );
    }

    final uri = Uri.parse(baseUrl);
    if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      throw StateError('API_BASE_URL must be an absolute HTTP or HTTPS URL.');
    }

    return uri.resolve(path);
  }

  static Uri get resumeScreenEndpoint => _resolve('/api/resumes/screen');

  static Uri get resumeEmbeddingEndpoint => _resolve('/api/resumes/embed');

  static Uri jobEmbeddingEndpoint(String jobId) =>
      _resolve('/api/jobs/${Uri.encodeComponent(jobId)}/embed');

  static Uri jobMatchesEndpoint(String jobId) =>
      _resolve('/api/jobs/${Uri.encodeComponent(jobId)}/matches')
          .replace(queryParameters: {'limit': '100'});

  // background=true: the server answers at once and keeps matching.
  static Uri jobMatchEndpoint(String jobId) =>
      _resolve('/api/jobs/${Uri.encodeComponent(jobId)}/match')
          .replace(queryParameters: {'background': 'true'});

  static Uri candidateResumeEndpoint(String uid) =>
      _resolve('/api/candidates/${Uri.encodeComponent(uid)}/resume');

  // The signed-in candidate's own profile and job-match results.
  static Uri get myInsightsEndpoint => _resolve('/api/candidates/me/insights');
}
