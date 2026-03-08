import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/scan_mode_controller.dart';
import 'detection_response_sanitizer.dart';

class VideoDetectionService {
  static Future<Map<String, dynamic>> detectAI(File video) async {
    const maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${ApiConfig.baseUrl}/detect/video').replace(
            queryParameters: {'mode': ScanModeController.apiValue},
          ),
        );

        request.files.add(
          await http.MultipartFile.fromPath('file', video.path),
        );

        final streamedResponse =
            await request.send().timeout(const Duration(seconds: 120));
        final response = await http.Response.fromStream(streamedResponse);

        final body = response.body.trim();
        Map<String, dynamic>? decoded;
        if (body.isNotEmpty) {
          final json = jsonDecode(body);
          if (json is Map<String, dynamic>) decoded = json;
        }

        if (response.statusCode != 200) {
          return DetectionResponseSanitizer.sanitize(
            'video',
            decoded,
            success: false,
            error: 'Video detection failed (${response.statusCode})',
          );
        }

        return DetectionResponseSanitizer.sanitize('video', decoded);
      } on TimeoutException {
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        return DetectionResponseSanitizer.failure('video', 'Request timed out');
      } catch (e) {
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        return DetectionResponseSanitizer.failure('video', e.toString());
      }
    }
    return DetectionResponseSanitizer.failure('video', 'Unknown request failure');
  }
}
