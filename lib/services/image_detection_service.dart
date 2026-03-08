import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/scan_mode_controller.dart';
import 'detection_response_sanitizer.dart';

class ImageDetectionService {
  static Future<Map<String, dynamic>> detectAI(File image) async {
    const maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${ApiConfig.baseUrl}/detect/image').replace(
            queryParameters: {'mode': ScanModeController.apiValue},
          ),
        );

        request.files.add(
          await http.MultipartFile.fromPath('file', image.path),
        );

        final streamedResponse =
            await request.send().timeout(const Duration(seconds: 60));
        final response = await http.Response.fromStream(streamedResponse);

        final body = response.body.trim();
        Map<String, dynamic>? decoded;
        if (body.isNotEmpty) {
          final json = jsonDecode(body);
          if (json is Map<String, dynamic>) decoded = json;
        }

        if (response.statusCode != 200) {
          return DetectionResponseSanitizer.sanitize(
            'image',
            decoded,
            success: false,
            error: 'Image detection failed (${response.statusCode})',
          );
        }

        return DetectionResponseSanitizer.sanitize('image', decoded);
      } on TimeoutException {
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        return DetectionResponseSanitizer.failure('image', 'Request timed out');
      } catch (e) {
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        return DetectionResponseSanitizer.failure('image', e.toString());
      }
    }
    return DetectionResponseSanitizer.failure('image', 'Unknown request failure');
  }
}
