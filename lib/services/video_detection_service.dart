import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/scan_mode_controller.dart';
import 'detection_response_sanitizer.dart';

class VideoDetectionService {
  static Future<Map<String, dynamic>> detectAI(File video) async {
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
          await request.send().timeout(const Duration(seconds: 40));
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
      return DetectionResponseSanitizer.failure('video', 'Request timed out');
    } catch (e) {
      return DetectionResponseSanitizer.failure('video', e.toString());
    }
  }
}
