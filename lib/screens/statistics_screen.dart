import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/history_service.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Statistics'),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('scan_history').listenable(),
        builder: (context, box, _) {
          final scans = HistoryService.getAllScans();

          int total = scans.length;
          int aiCount = 0;
          int humanCount = 0;

          for (var scan in scans) {
            final result = HistoryService.normalizeMap(scan['result']);
            final label = result['label'] ?? '';

            if (label.toLowerCase().contains('ai')) {
              aiCount++;
            } else {
              humanCount++;
            }
          }

          double aiPercentage =
          total == 0 ? 0 : (aiCount / total) * 100;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: total == 0
                ? const Center(
              child: Text(
                'No data available',
                style: TextStyle(fontSize: 16),
              ),
            )
                : Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _statCard(
                    'Total Scans', total.toString()),
                _statCard(
                    'AI Generated', aiCount.toString()),
                _statCard(
                    'Human Made', humanCount.toString()),
                _statCard(
                    'AI Percentage',
                    '${aiPercentage.toStringAsFixed(1)}%'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
