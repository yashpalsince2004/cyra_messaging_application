import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cyra/features/chat/domain/chat_model.dart';
import 'package:cyra/features/chat/presentation/widgets/chat_list_item.dart';
import 'package:cyra/features/chat/presentation/screens/chat_screen.dart';
import 'package:cyra/features/chat/data/chat_repository.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ArchivedChatsScreen extends StatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  State<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<ArchivedChatsScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;
  late final ChatRepository _chatRepo;

  @override
  void initState() {
    super.initState();
    _chatRepo = ChatRepository(
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instance,
    );
  }

  ChatModel _buildChatModelFromDoc(Map<String, dynamic> data, String currentUserId) {
    bool isGroup = data['is_group'] ?? false;
    String contactName = 'Unknown';
    String? contactAvatar;

    if (isGroup) {
      contactName = data['group_name'] ?? 'Unnamed Group';
      contactAvatar = data['group_icon'];
    } else {
      contactName = 'Chat Partner';
    }

    return ChatModel(
      id: data['chat_id'] ?? '',
      contactName: contactName,
      contactAvatar: contactAvatar,
      lastMessage: data['last_message'] ?? '',
      timestamp: (data['last_message_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isGroup: isGroup,
      isSentByMe: data['last_sender'] == currentUserId,
      isPinned: data['is_pinned_$currentUserId'] ?? false,
      isArchived: data['is_archived_$currentUserId'] ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived'),
      ),
      body: _currentUser == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: _currentUser.uid)
                  .where('is_archived_${_currentUser.uid}', isEqualTo: true)
                  .orderBy('last_message_time', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No archived chats.'));
                }

                var archivedChats = snapshot.data!.docs.map((doc) {
                  return _buildChatModelFromDoc(
                      doc.data() as Map<String, dynamic>, _currentUser.uid);
                }).toList();

                return ListView.builder(
                  itemCount: archivedChats.length,
                  itemBuilder: (context, index) {
                    final chat = archivedChats[index];
                    return Dismissible(
                      key: Key(chat.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        await _chatRepo.archiveChat(chat.id, _currentUser.uid, false);
                        return false; 
                      },
                      background: Container(
                        color: Colors.green,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.unarchive, color: Colors.white),
                      ),
                      child: ChatListItem(
                        chat: chat,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(chat: chat),
                            ),
                          );
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
