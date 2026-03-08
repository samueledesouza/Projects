import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';

class ApiWarmupService {
  static Future<void> warmup() async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final uri = Uri.parse('${ApiConfig.baseUrl}/health');
        await http.get(uri).timeout(const Duration(seconds: 20));
        return;
      } catch (_) {
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
  }
}
