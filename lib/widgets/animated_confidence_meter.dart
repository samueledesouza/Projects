import 'package:flutter/material.dart';

class AnimatedConfidenceMeter extends StatelessWidget {
  final double value;
  final Color color;

  const AnimatedConfidenceMeter({
    super.key,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        return SizedBox(
          height: 160,
          width: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: val / 100,
                strokeWidth: 12,
                backgroundColor: Colors.grey.withOpacity(0.2),
                color: color,
              ),
              Text(
                '${val.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
