import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cyra/features/auth/domain/user_model.dart';
import 'package:cyra/features/chat/data/chat_repository.dart';

class GroupDetailsScreen extends ConsumerStatefulWidget {
  final List<UserModel> selectedUsers;

  const GroupDetailsScreen({super.key, required this.selectedUsers});

  @override
  ConsumerState<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends ConsumerState<GroupDetailsScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  File? _groupImage;
  bool _isLoading = false;

  void _pickGroupImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image != null) {
      setState(() {
        _groupImage = File(image.path);
      });
    }
  }

  void _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group subject')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final chatRepo = ref.read(chatRepositoryProvider);
    final participantIds = widget.selectedUsers.map((u) => u.uid).toList();

    try {
      await chatRepo.createGroupChat(
        groupName: groupName,
        participantIds: participantIds,
        profilePic: _groupImage,
        creatorId: currentUserId,
      );

      // Successfully created, pop twice to go back to Home screen
      if (mounted) {
        Navigator.pop(context); // Pop details screen
        Navigator.pop(context); // Pop selection screen
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New group'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _pickGroupImage,
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                          backgroundImage: _groupImage != null ? FileImage(_groupImage!) : null,
                          child: _groupImage == null
                              ? const Icon(Icons.camera_alt, color: Colors.grey)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _groupNameController,
                          decoration: const InputDecoration(
                            hintText: 'Type group subject here...',
                            border: UnderlineInputBorder(),
                          ),
                          maxLength: 25,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Participants',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: widget.selectedUsers.length,
                      itemBuilder: (context, index) {
                        final user = widget.selectedUsers[index];
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: theme.colorScheme.secondaryContainer,
                              child: Text(
                                user.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.name.split(' ')[0], // First name
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              onPressed: _createGroup,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.check, color: Colors.white),
            ),
    );
  }
}
