import 'package:flutter/foundation.dart';

enum ScanMode { fast, accurate }

class ScanModeController {
  static final ValueNotifier<ScanMode> mode =
      ValueNotifier<ScanMode>(ScanMode.accurate);

  static String get apiValue =>
      mode.value == ScanMode.fast ? 'fast' : 'accurate';
}
