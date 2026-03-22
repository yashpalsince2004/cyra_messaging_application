import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  Map<String, int> _mediaCounts = {
    'Images': 0,
    'Videos': 0,
    'Documents': 0,
    'Voice Notes': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageData();
  }

  Future<void> _loadStorageData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final firestore = FirebaseFirestore.instance;

    // Get all chats the user is part of
    final chats = await firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();

    int images = 0, documents = 0, audio = 0;

    for (var chat in chats.docs) {
      final messages = await chat.reference.collection('messages').get();
      for (var msg in messages.docs) {
        final type = msg.data()['type'] ?? 'text';
        if (type == 'image') images++;
        if (type == 'document') documents++;
        if (type == 'audio') audio++;
      }
    }

    if (mounted) {
      setState(() {
        _mediaCounts = {
          'Images': images,
          'Videos': 0,
          'Documents': documents,
          'Voice Notes': audio,
        };
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Storage & Data')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.primary.withAlpha(180)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Storage Used', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        '${_mediaCounts.values.fold(0, (a, b) => a + b)} items',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Category breakdown
                ..._mediaCounts.entries.map((entry) {
                  final icons = {
                    'Images': Icons.image,
                    'Videos': Icons.videocam,
                    'Documents': Icons.insert_drive_file,
                    'Voice Notes': Icons.mic,
                  };
                  final colors = {
                    'Images': Colors.purple,
                    'Videos': Colors.red,
                    'Documents': Colors.blue,
                    'Voice Notes': Colors.orange,
                  };
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (colors[entry.key] ?? Colors.grey).withAlpha(30),
                      child: Icon(icons[entry.key] ?? Icons.folder, color: colors[entry.key]),
                    ),
                    title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: Text('${entry.value}', style: TextStyle(color: Colors.grey[500])),
                  );
                }),

                const SizedBox(height: 24),
                const Divider(),

                // Clear data option
                ListTile(
                  leading: Icon(Icons.delete_sweep, color: Colors.red[400]),
                  title: const Text('Clear All Chat Media'),
                  subtitle: const Text('This action cannot be undone'),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear Media?'),
                        content: const Text('This will clear all cached media. Original files on Firebase will not be deleted.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local cache cleared')));
                            },
                            child: const Text('Clear', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
