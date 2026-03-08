import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../services/text_detection_service.dart';
import '../services/history_service.dart';
import '../widgets/primary_button.dart';
import 'result_screen.dart';

class TextScanScreen extends StatefulWidget {
  const TextScanScreen({super.key});

  @override
  State<TextScanScreen> createState() => _TextScanScreenState();
}

class _TextScanScreenState extends State<TextScanScreen> {
  final controller = TextEditingController();
  bool loading = false;

  void _warn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> analyze() async {
    final text = controller.text.trim();
    if (text.isEmpty) {
      _warn('Please enter text before analyzing.');
      return;
    }
    if (text.length > DetectionLimits.maxTextCharacters) {
      _warn(
        'Text too long. Maximum ${DetectionLimits.maxTextCharacters} characters allowed.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      final result = await TextDetectionService.detectAI(text);

      if (!mounted) return;

      // ✅ SAVE TO HISTORY
      HistoryService.addScan(
        type: 'text',
        result: result,
      );

      setState(() => loading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: {
              ...result,
              'type': 'text',
            },
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final charCount = controller.text.length;
    final tooLong = charCount > DetectionLimits.maxTextCharacters;
    final canAnalyze = !loading && charCount > 0 && !tooLong;

    return Scaffold(
      appBar: AppBar(title: const Text('Text Scan')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: controller,
              maxLines: 8,
              onChanged: (_) => setState(() {}),
              maxLengthEnforcement: MaxLengthEnforcement.none,
              textInputAction: TextInputAction.done,
              maxLength: DetectionLimits.maxTextCharacters,
              decoration: const InputDecoration(
                hintText: 'Paste text here...',
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Limit: ${DetectionLimits.maxTextCharacters} characters',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (tooLong)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'You exceeded the character limit. Reduce text to continue.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: 'Analyze',
              onPressed: canAnalyze ? analyze : null,
              loading: loading,
            ),
          ],
        ),
      ),
    );
  }
}
