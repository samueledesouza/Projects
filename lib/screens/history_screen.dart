import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/history_service.dart';
import '../screens/result_screen.dart'; // ✅ IMPORTANT


class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _showEvictMenu(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.filter_alt_outlined),
                title: const Text('Keep latest 50'),
                onTap: () => Navigator.pop(context, 'keep_50'),
              ),
              ListTile(
                leading: const Icon(Icons.filter_alt_outlined),
                title: const Text('Keep latest 20'),
                onTap: () => Navigator.pop(context, 'keep_20'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Clear all history'),
                onTap: () => Navigator.pop(context, 'clear_all'),
              ),
            ],
          ),
        );
      },
    );

    if (action == null) return;
    if (action == 'keep_50') {
      await HistoryService.keepLatest(50);
    } else if (action == 'keep_20') {
      await HistoryService.keepLatest(20);
    } else if (action == 'clear_all') {
      await HistoryService.clear();
    }
  }

  double _safeToDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showEvictMenu(context),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('scan_history').listenable(),
        builder: (context, box, _) {
          final scans = HistoryService.getAllScans();

          if (scans.isEmpty) {
            return const Center(
              child: Text(
                'No scans yet',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: scans.length,
            itemBuilder: (context, index) {
              final scan = scans[index];
              final result = HistoryService.normalizeMap(scan['result']);

              final double ai =
                  _safeToDouble(
                    result['ai_probability'] ?? result['ai_confidence'] ?? 0,
                  );

              final String label =
                  result['label'] ?? 'Unknown Result';

              final String type =
                  scan['type'] ?? 'unknown';

              IconData icon;
              switch (type) {
                case 'text':
                  icon = Icons.text_fields;
                  break;
                case 'image':
                  icon = Icons.image;
                  break;
                case 'audio':
                  icon = Icons.mic;
                  break;
                case 'video':
                  icon = Icons.videocam;
                  break;
                default:
                  icon = Icons.insert_drive_file;
              }

              return Card(
                elevation: 4,
                margin:
                const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(icon),
                  title: Text(label),
                  subtitle: Text(
                    'AI: ${ai.toStringAsFixed(1)}% • $type',
                  ),
                  trailing:
                  const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResultScreen(
                          result: HistoryService.normalizeMap(result),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
