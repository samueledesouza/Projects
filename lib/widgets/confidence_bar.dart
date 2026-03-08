import 'package:flutter/material.dart';

class ConfidenceBar extends StatelessWidget {
  final double value;
  final String label;

  const ConfidenceBar({
    super.key,
    required this.value,
    required this.label,
  });

  Color _color(double v) {
    if (v >= 80) return Colors.red;
    if (v >= 60) return Colors.deepOrange;
    if (v >= 40) return Colors.amber;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label (${value.toStringAsFixed(1)}%)',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 10,
            backgroundColor: Colors.grey.shade300,
            color: _color(value),
          ),
        ),
      ],
    );
  }
}
