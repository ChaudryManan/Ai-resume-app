class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static Uri get resumeEmbeddingEndpoint {
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

    return uri.resolve('/api/resumes/embed');
  }

  static Uri jobEmbeddingEndpoint(String jobId) {
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

    return uri.resolve('/api/jobs/${Uri.encodeComponent(jobId)}/embed');
  }
}
