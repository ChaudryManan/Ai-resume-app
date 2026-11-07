class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static Uri _resolve(String path) {
    if (baseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is not configured. Start the backend and pass '
        '--dart-define=API_BASE_URL=<backend-url> to Flutter.',
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
}
