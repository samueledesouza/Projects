import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../core/scan_mode_controller.dart';
import 'detection_response_sanitizer.dart';

class AudioDetectionService {
  static Future<Map<String, dynamic>> detectAI(File audio) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/detect/audio').replace(
          queryParameters: {'mode': ScanModeController.apiValue},
        ),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', audio.path),
      );

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      final body = response.body.trim();
      Map<String, dynamic>? decoded;
      if (body.isNotEmpty) {
        final json = jsonDecode(body);
        if (json is Map<String, dynamic>) decoded = json;
      }

      if (response.statusCode != 200) {
        return DetectionResponseSanitizer.sanitize(
          'audio',
          decoded,
          success: false,
          error: 'Audio detection failed (${response.statusCode})',
        );
      }

      return DetectionResponseSanitizer.sanitize('audio', decoded);
    } on TimeoutException {
      return DetectionResponseSanitizer.failure('audio', 'Request timed out');
    } catch (e) {
      return DetectionResponseSanitizer.failure('audio', e.toString());
    }
  }
}
