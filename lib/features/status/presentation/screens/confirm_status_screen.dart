import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cyra/features/status/data/status_repository.dart';

class ConfirmStatusScreen extends ConsumerStatefulWidget {
  final File file;

  const ConfirmStatusScreen({
    super.key,
    required this.file,
  });

  @override
  ConsumerState<ConfirmStatusScreen> createState() => _ConfirmStatusScreenState();
}

class _ConfirmStatusScreenState extends ConsumerState<ConfirmStatusScreen> {
  bool _isUploading = false;

  void addStatus() async {
    setState(() {
      _isUploading = true;
    });

    try {
      final statusRepo = ref.read(statusRepositoryProvider);
      await statusRepo.uploadStatus(widget.file);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Status'),
        backgroundColor: Colors.black, // Typical for media previews
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Image.file(widget.file),
        ),
      ),
      floatingActionButton: _isUploading 
        ? const CircularProgressIndicator()
        : FloatingActionButton(
            onPressed: addStatus,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.send, color: Colors.white),
          ),
    );
  }
}
