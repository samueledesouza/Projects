import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants.dart';
import '../services/image_detection_service.dart';
import '../services/history_service.dart';
import '../widgets/primary_button.dart';
import 'result_screen.dart';

class ImageScanScreen extends StatefulWidget {
  const ImageScanScreen({super.key});

  @override
  State<ImageScanScreen> createState() => _ImageScanScreenState();
}

class _ImageScanScreenState extends State<ImageScanScreen> {
  File? image;
  int? imageBytes;
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

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked != null && mounted) {
      final file = File(picked.path);
      final bytes = await file.length();
      setState(() {
        image = file;
        imageBytes = bytes;
      });
      if (bytes > DetectionLimits.maxImageBytes) {
        _warn(
          'Image too large (${_formatBytes(bytes)}). Max allowed is ${_formatBytes(DetectionLimits.maxImageBytes)}.',
        );
      }
    }
  }

  Future<void> analyze() async {
    if (image == null || loading) return;
    final bytes = imageBytes ?? await image!.length();
    if (bytes > DetectionLimits.maxImageBytes) {
      _warn(
        'Image size exceeds limit. Please choose an image under ${_formatBytes(DetectionLimits.maxImageBytes)}.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      final result = await ImageDetectionService.detectAI(image!);

      HistoryService.addScan(
        type: 'image',
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
              'type': 'image',
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
    final tooLarge = (imageBytes ?? 0) > DetectionLimits.maxImageBytes;
    final canAnalyze = image != null && !loading && !tooLarge;

    return Scaffold(
      appBar: AppBar(title: const Text('Image Scan')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            image == null
                ? Container(
              height: 200,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text('No image selected'),
            )
                : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(image!, height: 200),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Limit: ${_formatBytes(DetectionLimits.maxImageBytes)} image size',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (imageBytes != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Selected: ${_formatBytes(imageBytes!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (tooLarge)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Selected image is above the allowed size limit.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            PrimaryButton(
              text: 'Pick Image',
              onPressed: loading ? null : pickImage,
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
