import 'package:hive/hive.dart';

class HistoryService {
  static final Box _box = Hive.box('scan_history');

  static Map<String, dynamic> _deepMap(dynamic value) {
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((k, v) {
        out[k.toString()] = _deepValue(v);
      });
      return out;
    }
    return <String, dynamic>{};
  }

  static dynamic _deepValue(dynamic value) {
    if (value is Map) {
      return _deepMap(value);
    }
    if (value is List) {
      return value.map(_deepValue).toList();
    }
    return value;
  }

  static Map<String, dynamic> normalizeMap(dynamic value) {
    return _deepMap(value);
  }

  static void addScan({
    required String type, // "text" or "image"
    required Map<String, dynamic> result,
  }) {
    _box.add({
      'type': type,
      'result': normalizeMap(result),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static List<Map<String, dynamic>> getAllScans() {
    return _box.values.map((e) => normalizeMap(e)).toList().reversed.toList();
  }

  static Future<void> clear() async {
    await _box.clear();
  }

  static Future<void> keepLatest(int count) async {
    if (count < 0) return;
    final total = _box.length;
    final removeCount = total - count;
    if (removeCount <= 0) return;

    await _box.deleteAll(List<int>.generate(removeCount, (i) => i));
  }
}
