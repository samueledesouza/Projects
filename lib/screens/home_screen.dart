import 'package:flutter/material.dart';
import 'text_scan_screen.dart';
import 'image_scan_screen.dart';
import 'audio_scan_screen.dart';
import 'video_scan_screen.dart';
import 'history_screen.dart';
import 'statistics_screen.dart';
import '../widgets/theme_toggle_button.dart';
import '../core/scan_mode_controller.dart';
import '../services/api_warmup_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    // Warm up backend so first real scan is less likely to timeout.
    ApiWarmupService.warmup();
  }

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detectify AI"),
        centerTitle: true,
        actions: const [
          ThemeToggleButton(),
        ],
      ),

      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                  Color.lerp(
                    const Color(0xFF1B1B2F),
                    const Color(0xFF222244),
                    _controller.value,
                  )!,
                  const Color(0xFF0D0D18),
                ]
                    : [
                  Color.lerp(
                    const Color(0xFFE3F2FD),
                    const Color(0xFFBBDEFB),
                    _controller.value,
                  )!,
                  const Color(0xFFF7FBFF),
                ],
              ),
            ),

            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const SizedBox(height: 10),

                    /// HEADER
                    Text(
                      "AI Content Detector",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Analyze text, images, audio and videos\nfor AI-generated content instantly.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(.8),
                      ),
                    ),

                    const SizedBox(height: 32),

                    ValueListenableBuilder<ScanMode>(
                      valueListenable: ScanModeController.mode,
                      builder: (context, mode, _) {
                        final isFast = mode == ScanMode.fast;
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: theme.colorScheme.surface.withOpacity(.65),
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tune, size: 18),
                              const SizedBox(width: 10),
                              const Text(
                                'Scan Mode',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              ChoiceChip(
                                label: const Text('Fast'),
                                selected: isFast,
                                onSelected: (_) => ScanModeController.mode.value = ScanMode.fast,
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Accurate'),
                                selected: !isFast,
                                onSelected: (_) => ScanModeController.mode.value = ScanMode.accurate,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    /// SCAN OPTIONS

                    _buildScanCard(
                      icon: Icons.text_snippet_outlined,
                      title: "Scan Text",
                      color: Colors.blueAccent,
                      onTap: () => _navigate(const TextScanScreen()),
                    ),

                    _buildScanCard(
                      icon: Icons.image_outlined,
                      title: "Scan Image",
                      color: Colors.purpleAccent,
                      onTap: () => _navigate(const ImageScanScreen()),
                    ),

                    _buildScanCard(
                      icon: Icons.audiotrack_outlined,
                      title: "Scan Audio",
                      color: Colors.orangeAccent,
                      onTap: () => _navigate(const AudioScanScreen()),
                    ),

                    _buildScanCard(
                      icon: Icons.videocam_outlined,
                      title: "Scan Video",
                      color: Colors.greenAccent,
                      onTap: () => _navigate(const VideoScanScreen()),
                    ),

                    const SizedBox(height: 28),

                    /// ACTION BUTTONS

                    _buildActionButton(
                      icon: Icons.history,
                      label: "View Scan History",
                      onTap: () => _navigate(const HistoryScreen()),
                    ),

                    const SizedBox(height: 14),

                    _buildActionButton(
                      icon: Icons.bar_chart,
                      label: "View Statistics",
                      onTap: () => _navigate(const StatisticsScreen()),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// SCAN CARD
  Widget _buildScanCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),

      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,

        child: Container(
          padding: const EdgeInsets.all(18),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: theme.colorScheme.surface.withOpacity(.65),

            border: Border.all(
              color: theme.dividerColor.withOpacity(.15),
            ),

            boxShadow: [
              BoxShadow(
                color: color.withOpacity(.25),
                blurRadius: 25,
                offset: const Offset(0, 10),
              )
            ],
          ),

          child: Row(
            children: [

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(.2),
                ),
                child: Icon(icon, color: color, size: 26),
              ),

              const SizedBox(width: 20),

              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),

              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.iconTheme.color?.withOpacity(.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ACTION BUTTONS
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),

        elevation: 0,
      ),

      icon: Icon(icon),
      label: Text(label),
      onPressed: onTap,
    );
  }

  /// NAVIGATION
  void _navigate(Widget screen) {

    Navigator.push(
      context,

      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,

        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
