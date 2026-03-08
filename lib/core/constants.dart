import 'package:flutter/material.dart';


class AppColors {
  static const background = Color(0xFF0F1220);
  static const primary = Color(0xFF6C63FF);
  static const secondary = Color(0xFF8E88FF);
  static const textLight = Colors.white;
  static const textMuted = Colors.grey;
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFC107);
  static const danger  = Color(0xFFE53935);

}

class DetectionLimits {
  static const int maxTextCharacters = 4000;
  static const int maxImageBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxAudioBytes = 25 * 1024 * 1024; // 25 MB
  static const int maxVideoBytes = 80 * 1024 * 1024; // 80 MB
}
