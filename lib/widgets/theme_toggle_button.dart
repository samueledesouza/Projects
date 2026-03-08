import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme_controller.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, themeController, _) {
        final isDark =
            themeController.themeMode == ThemeMode.dark;

        return Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context)
                .colorScheme
                .surface
                .withOpacity(0.2),
          ),
          child: IconButton(
            tooltip: isDark
                ? "Switch to Light Mode"
                : "Switch to Dark Mode",
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  RotationTransition(
                    turns: animation,
                    child: child,
                  ),
              child: Icon(
                isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                key: ValueKey(isDark),
              ),
            ),
            onPressed: () {
              themeController.toggleTheme();
            },
          ),
        );
      },
    );
  }
}
