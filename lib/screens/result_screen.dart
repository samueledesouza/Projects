import 'package:flutter/material.dart';
import '../widgets/animated_confidence_meter.dart';
import '../widgets/explainability_graph.dart';
import '../services/history_service.dart';
import '../widgets/theme_toggle_button.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;

  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  bool showWhy = false;

  @override
  void initState() {
    super.initState();

    if (widget.result['cached'] != true) {
      HistoryService.addScan(
        type: widget.result['type'] ?? 'unknown',
        result: widget.result,
      );
    }
  }

  Color _aiColor(double ai) {
    if (ai >= 80) return Colors.red.shade400;
    if (ai >= 60) return Colors.orange.shade400;
    if (ai >= 40) return Colors.amber.shade600;
    return Colors.green.shade400;
  }

  String _confidenceLabel(double ai) {
    if (ai >= 80) return 'Very High AI Likelihood';
    if (ai >= 60) return 'High AI Likelihood';
    if (ai >= 40) return 'Mixed / Inconclusive';
    return 'Likely Human Generated';
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    final double ai =
    (result['ai_probability'] ?? 0).toDouble();

    final double human =
    (result['human_probability'] ?? (100 - ai)).toDouble();

    final String label = result['label'] ?? 'Unknown Result';
    final String model = result['model'] ?? 'Model';
    final bool success = result['success'] != false;
    final String? errorMessage =
        result['error'] is String ? result['error'] as String : null;

    // ================= NEW EXPLAINABILITY =================
    final Map<String, dynamic>? explainability =
    result['explainability'];

    final String summary =
        explainability?['summary'] ?? '';

    final List reasoning =
        explainability?['model_reasoning'] ??
            explainability?['signals'] ??
            [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Result'),
        actions: const [
          ThemeToggleButton(),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _aiColor(ai),
              ),
            ),
            if (!success) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.35)),
                ),
                child: Text(
                  errorMessage ?? 'The analysis completed with limited data.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              model,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Chip(
              backgroundColor: _aiColor(ai).withOpacity(0.15),
              label: Text(
                _confidenceLabel(ai),
                style: TextStyle(
                  color: _aiColor(ai),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: AnimatedConfidenceMeter(
                value: ai,
                color: _aiColor(ai),
              ),
            ),
            const SizedBox(height: 24),
            ExplainabilityGraph(
              ai: ai,
              human: human,
            ),
            const SizedBox(height: 32),

            // ================= WHY SECTION =================
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() => showWhy = !showWhy);
                      },
                      child: Row(
                        children: [
                          Icon(showWhy
                              ? Icons.expand_less
                              : Icons.expand_more),
                          const SizedBox(width: 8),
                          const Text(
                            'Why this result?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showWhy) ...[
                      const SizedBox(height: 12),

                      // Summary
                      if (summary.isNotEmpty)
                        Padding(
                          padding:
                          const EdgeInsets.only(
                              bottom: 12),
                          child: Text(
                            summary,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),

                      // Detailed reasoning
                      if (reasoning.isNotEmpty)
                        for (final item in reasoning)
                          Padding(
                            padding:
                            const EdgeInsets.only(
                                bottom: 8),
                            child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              children: [
                                const Text('• '),
                                Expanded(
                                  child: Text(
                                    item.toString(),
                                    style:
                                    const TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                      if (reasoning.isEmpty &&
                          summary.isEmpty)
                        const Text(
                          "Explainability data unavailable.",
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle:
                            FontStyle.italic,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 40),

            if (result['cached'] == true)
              const Text(
                'Result served from cache',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),

          ],
        ),
      ),
    );
  }
}
