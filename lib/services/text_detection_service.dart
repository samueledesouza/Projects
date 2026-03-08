import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/scan_mode_controller.dart';
import 'detection_response_sanitizer.dart';

class TextDetectionService {
  static Future<Map<String, dynamic>> detectAI(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return DetectionResponseSanitizer.failure('text', 'Text cannot be empty');
    }

    const maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse('${ApiConfig.baseUrl}/detect/text').replace(
                queryParameters: {'mode': ScanModeController.apiValue},
              ),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'text': trimmed}),
            )
            .timeout(const Duration(seconds: 60));

        final body = response.body.trim();
        Map<String, dynamic>? decoded;
        if (body.isNotEmpty) {
          final json = jsonDecode(body);
          if (json is Map<String, dynamic>) decoded = json;
        }

        if (response.statusCode != 200) {
          return DetectionResponseSanitizer.sanitize(
            'text',
            decoded,
            success: false,
            error: 'Text detection failed (${response.statusCode})',
          );
        }

        return DetectionResponseSanitizer.sanitize('text', decoded);
      } on TimeoutException {
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        return DetectionResponseSanitizer.failure('text', 'Request timed out');
      } catch (e) {
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        return DetectionResponseSanitizer.failure('text', e.toString());
      }
    }
    return DetectionResponseSanitizer.failure('text', 'Unknown request failure');
  }
}
