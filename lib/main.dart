import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'core/theme_controller.dart';
import 'core/theme.dart';       // AppTheme

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Open scan history box
  await Hive.openBox('scan_history');

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: const DetectifyApp(),
    ),
  );
}

class DetectifyApp extends StatelessWidget {
  const DetectifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Detectify AI',

      // 🔁 Dynamic theme switching
      themeMode: themeController.themeMode,

      // ☀️ Light theme (optional if you only designed dark)
      theme: AppTheme.lightTheme,

      // 🌙 Your existing dark theme
      darkTheme: AppTheme.darkTheme,

      home: const HomeScreen(),
    );
  }
}
