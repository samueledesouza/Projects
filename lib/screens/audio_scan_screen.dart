import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../core/constants.dart';
import '../services/audio_detection_service.dart';
import '../services/history_service.dart';
import '../widgets/primary_button.dart';
import 'result_screen.dart';

class AudioScanScreen extends StatefulWidget {
  const AudioScanScreen({super.key});

  @override
  State<AudioScanScreen> createState() => _AudioScanScreenState();
}

class _AudioScanScreenState extends State<AudioScanScreen> {
  File? audio;
  int? audioBytes;
  bool loading = false;

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  void _warn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
    );

    if (!mounted) return;

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.length();
      setState(() {
        audio = file;
        audioBytes = bytes;
      });
      if (bytes > DetectionLimits.maxAudioBytes) {
        _warn(
          'Audio too large (${_formatBytes(bytes)}). Max allowed is ${_formatBytes(DetectionLimits.maxAudioBytes)}.',
        );
      }
    }
  }

  Future<void> analyze() async {
    if (audio == null || loading) return;
    final bytes = audioBytes ?? await audio!.length();
    if (bytes > DetectionLimits.maxAudioBytes) {
      _warn(
        'Audio size exceeds limit. Please choose a file under ${_formatBytes(DetectionLimits.maxAudioBytes)}.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      final result = await AudioDetectionService.detectAI(audio!);

      HistoryService.addScan(
        type: 'audio',
        result: result,
      );

      if (!mounted) return;

      setState(() => loading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: {
              ...result,
              'type': 'audio',
            },
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio analysis failed. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tooLarge = (audioBytes ?? 0) > DetectionLimits.maxAudioBytes;
    final canAnalyze = audio != null && !loading && !tooLarge;

    return Scaffold(
      appBar: AppBar(title: const Text('Audio Scan')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              height: 120,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.audiotrack, size: 32, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    audio == null
                        ? 'No audio selected'
                        : audio!.path.split('/').last,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Limit: ${_formatBytes(DetectionLimits.maxAudioBytes)} audio size',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (audioBytes != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Selected: ${_formatBytes(audioBytes!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (tooLarge)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Selected audio is above the allowed size limit.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            PrimaryButton(
              text: 'Pick Audio',
              onPressed: loading ? null : pickAudio,
            ),
            const SizedBox(height: 12),
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
