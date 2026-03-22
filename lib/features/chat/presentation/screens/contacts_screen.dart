import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cyra/features/auth/domain/user_model.dart';
import 'package:cyra/features/chat/domain/chat_model.dart';
import 'package:cyra/features/chat/presentation/screens/chat_screen.dart';
import 'package:cyra/features/chat/presentation/screens/create_group_screen.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final String? currentUserId = currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('user_db').snapshots(),
          builder: (context, snapshot) {
            int contactCount = 0;
            if (snapshot.hasData) {
              contactCount = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['user_id'] != currentUser?.uid;
              }).length;
            }
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal)),
                Text('$contactCount contacts', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal)),
              ],
            );
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('user_db').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          // Filter out current user from the list
          final users = snapshot.data!.docs
              .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
              .where((user) => user.uid != currentUserId)
              .toList();

          return ListView.builder(
            itemCount: users.length + 1, // +1 for the "New Group" row
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primary,
                    child: const Icon(Icons.group_add, color: Colors.white),
                  ),
                  title: const Text('New group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateGroupScreen(),
                      ),
                    );
                  },
                );
              }

              final user = users[index - 1];
              final String name = user.name;
              final String email = user.email;
              final String phone = user.phoneNo;
              // Prefer phone if available, else email
              final String subtitleText = phone.isNotEmpty ? phone : email;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(name),
                subtitle: Text(subtitleText),
                onTap: () async {
                  // Setup or navigate to chat
                  final chat = ChatModel(
                    id: user.uid,
                    contactName: name,
                    lastMessage: '',
                    timestamp: DateTime.now(),
                  );
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(chat: chat),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
