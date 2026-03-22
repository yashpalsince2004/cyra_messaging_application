import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cyra/features/status/domain/status_model.dart';
import 'package:cyra/features/status/data/status_repository.dart';
import 'package:cyra/features/status/presentation/screens/confirm_status_screen.dart';
import 'package:cyra/features/status/presentation/screens/story_view_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmStatusScreen(file: File(pickedFile.path)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusRepo = ref.watch(statusRepositoryProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImage,
        child: const Icon(Icons.camera_alt),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // My Status Section
            ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[300],
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
              title: const Text('My status', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Tap to add status update'),
              onTap: _pickImage,
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Recent updates', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            ),

            // Contacts' Statuses
            StreamBuilder<List<StatusModel>>(
              stream: statusRepo.getStatuses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('No recent updates')),
                  );
                }

                // Exclude current user from "Recent Updates" list if desired, 
                // or keep them if we want to view our own status
                // WhatsApp separates "My status" but for simplicity, we view all here:
                var validStatuses = snapshot.data!;
                
                // Let's separate 'my status' from 'other statuses'
                StatusModel? myStatus;
                try {
                  myStatus = validStatuses.firstWhere((s) => s.uid == currentUserId);
                  validStatuses.removeWhere((s) => s.uid == currentUserId);
                } catch (e) {
                  // user has no status
                }

                return Column(
                  children: [
                    if (myStatus != null) ...[
                      const Divider(),
                      _buildStatusTile(myStatus, context, isMe: true),
                      const Divider(),
                    ],
                    ...validStatuses.map((status) {
                      return _buildStatusTile(status, context);
                    }),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile(StatusModel status, BuildContext context, {bool isMe = false}) {
    final theme = Theme.of(context);
    final String timeString = DateFormat('hh:mm a').format(status.createdAt);

    return ListTile(
      leading: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.primary, width: 2.5),
        ),
        child: CircleAvatar(
          radius: 22,
          backgroundImage: status.photoUrls.isNotEmpty 
              ? NetworkImage(status.photoUrls.last) 
              : null,
          child: status.photoUrls.isEmpty 
              ? Text(status.username.isNotEmpty ? status.username[0].toUpperCase() : '?')
              : null,
        ),
      ),
      title: Text(
        isMe ? 'My status' : status.username, 
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(isMe ? 'Tap to view' : timeString),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryViewScreen(status: status),
          ),
        );
      },
    );
  }
}
