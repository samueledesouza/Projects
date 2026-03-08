class DetectionResponseSanitizer {
  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static Map<String, dynamic> sanitize(
    String type,
    Map<String, dynamic>? raw, {
    bool success = true,
    String? error,
  }) {
    final source = raw ?? <String, dynamic>{};

    final ai = _toDouble(
      source['ai_probability'] ?? source['ai_confidence'],
      success ? 0 : 50,
    ).clamp(0, 100).toDouble();

    final human =
        _toDouble(source['human_probability'], 100 - ai).clamp(0, 100).toDouble();

    final result = <String, dynamic>{
      ...source,
      'success': source['success'] ?? success,
      'type': source['type'] ?? type,
      'ai_probability': ai,
      'human_probability': human,
      'label': source['label'] ?? (ai >= 60 ? 'AI-generated $type' : 'Likely human $type'),
      'confidence': source['confidence'] ??
          (ai >= 80
              ? 'Strong AI indicators'
              : ai >= 60
                  ? 'Moderate AI indicators'
                  : ai >= 40
                      ? 'Mixed signals'
                      : 'Low confidence'),
      'explainability': source['explainability'] ??
          {
            'version': 'fallback-1.0',
            'summary': success
                ? 'Detailed explainability was unavailable for this result.'
                : 'Analysis failed, so explainability could not be generated.',
            'model_reasoning': <String>[
              if (!success && error != null) error,
            ],
          },
      'signals': source['signals'] is Map<String, dynamic> ? source['signals'] : null,
    };

    if (error != null && error.isNotEmpty) {
      result['error'] = error;
    }

    return result;
  }

  static Map<String, dynamic> failure(String type, String message) {
    return sanitize(
      type,
      {
        'success': false,
        'label': 'Analysis unavailable',
        'ai_probability': 50,
        'human_probability': 50,
      },
      success: false,
      error: message,
    );
  }
}
