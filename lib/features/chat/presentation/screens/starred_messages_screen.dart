import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cyra/features/chat/data/chat_repository.dart';
import 'package:cyra/features/chat/domain/message_model.dart';
import 'package:intl/intl.dart';

class StarredMessagesScreen extends ConsumerWidget {
  const StarredMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatRepo = ref.watch(chatRepositoryProvider);
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Starred Messages')),
      body: currentUser == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: chatRepo.getStarredMessages(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final starred = snapshot.data ?? [];
                if (starred.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_border, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No starred messages', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: starred.length,
                  itemBuilder: (context, index) {
                    final msg = starred[index]['message'] as MessageModel;
                    final isMe = msg.senderId == currentUser.uid;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.star, color: Colors.amber[700]),
                      ),
                      title: Text(
                        msg.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                      subtitle: Text(
                        '${isMe ? 'You' : 'Contact'} • ${DateFormat('MMM d, HH:mm').format(msg.timestamp)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.star, color: Colors.amber),
                        onPressed: () {
                          chatRepo.toggleStarMessage(starred[index]['chatId'], msg.messageId, false);
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
