import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cyra/features/auth/domain/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  bool _isSaving = false;
  UserModel? _user;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firestore.collection('user_db').doc(uid).get();
    if (doc.exists) {
      final user = UserModel.fromMap(doc.data()!);
      _nameController.text = user.name;
      _aboutController.text = user.about;
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      String? photoUrl = _user?.photoUrl;

      // Upload new image if selected
      if (_pickedImage != null) {
        final ref = FirebaseStorage.instance.ref().child('profile_pics/$uid');
        await ref.putFile(_pickedImage!);
        photoUrl = await ref.getDownloadURL();
      }

      await _firestore.collection('user_db').doc(uid).update({
        'name': _nameController.text.trim(),
        'about': _aboutController.text.trim(),
        'photoUrl': photoUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _saveProfile,
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Picture
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!)
                        : (_user?.photoUrl != null
                            ? CachedNetworkImageProvider(_user!.photoUrl!)
                            : null) as ImageProvider?,
                    child: (_pickedImage == null && _user?.photoUrl == null)
                        ? Icon(Icons.person, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400])
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Name field
            _buildEditTile(
              icon: Icons.person,
              label: 'Name',
              controller: _nameController,
              hint: 'Enter your name',
            ),
            const SizedBox(height: 16),

            // About field
            _buildEditTile(
              icon: Icons.info_outline,
              label: 'About',
              controller: _aboutController,
              hint: 'Write something about yourself',
            ),
            const SizedBox(height: 16),

            // Email (read-only)
            ListTile(
              leading: Icon(Icons.email, color: theme.colorScheme.primary),
              title: const Text('Email', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey)),
              subtitle: Text(_user?.email ?? '', style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),

            // Phone (read-only)
            ListTile(
              leading: Icon(Icons.phone, color: theme.colorScheme.primary),
              title: const Text('Phone', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey)),
              subtitle: Text(_user?.phoneNo.isNotEmpty == true ? _user!.phoneNo : 'Not set', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditTile({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const UnderlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}
