import 'package:flutter/material.dart';

class ExplainabilityGraph extends StatelessWidget {
  final double ai;
  final double human;

  const ExplainabilityGraph({
    super.key,
    required this.ai,
    required this.human,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _bar('AI', ai, Colors.redAccent),
        const SizedBox(height: 10),
        _bar('Human', human, Colors.green),
      ],
    );
  }

  Widget _bar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(1)}%'),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value / 100,
          minHeight: 10,
          color: color,
          backgroundColor: Colors.grey.withOpacity(0.2),
        ),
      ],
    );
  }
}
