class ApiConfig {
  static const String _defaultBaseUrl = 'https://detectify-ai-api.onrender.com';
  static const String _envBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: _defaultBaseUrl);

  static String get baseUrl {
    final url = _envBaseUrl.trim();
    if (url.isEmpty) return _defaultBaseUrl;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
