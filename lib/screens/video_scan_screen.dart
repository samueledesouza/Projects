import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/constants.dart';
import '../services/video_detection_service.dart';
import '../services/history_service.dart';
import '../widgets/primary_button.dart';
import 'result_screen.dart';

class VideoScanScreen extends StatefulWidget {
  const VideoScanScreen({super.key});

  @override
  State<VideoScanScreen> createState() => _VideoScanScreenState();
}

class _VideoScanScreenState extends State<VideoScanScreen> {
  File? video;
  int? videoBytes;
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

  Future<void> pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
      );

      if (result != null && result.files.single.path != null && mounted) {
        final file = File(result.files.single.path!);
        final bytes = await file.length();
        setState(() {
          video = file;
          videoBytes = bytes;
        });
        if (bytes > DetectionLimits.maxVideoBytes) {
          _warn(
            'Video too large (${_formatBytes(bytes)}). Max allowed is ${_formatBytes(DetectionLimits.maxVideoBytes)}.',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video picker error: ${e.toString()}')),
      );
    }
  }

  Future<void> analyze() async {
    if (video == null || loading) return;
    final bytes = videoBytes ?? await video!.length();
    if (bytes > DetectionLimits.maxVideoBytes) {
      _warn(
        'Video size exceeds limit. Please choose a video under ${_formatBytes(DetectionLimits.maxVideoBytes)}.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      final result = await VideoDetectionService.detectAI(video!);

      HistoryService.addScan(
        type: 'video',
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
              'type': 'video',
            },
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tooLarge = (videoBytes ?? 0) > DetectionLimits.maxVideoBytes;
    final canAnalyze = video != null && !loading && !tooLarge;

    return Scaffold(
      appBar: AppBar(title: const Text('Video Scan')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              height: 140,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Text(
                video == null
                    ? 'No video selected'
                    : video!.path.split('/').last,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Limit: ${_formatBytes(DetectionLimits.maxVideoBytes)} video size',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (videoBytes != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Selected: ${_formatBytes(videoBytes!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (tooLarge)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Selected video is above the allowed size limit.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            PrimaryButton(
              text: 'Pick Video',
              onPressed: loading ? null : pickVideo,
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
