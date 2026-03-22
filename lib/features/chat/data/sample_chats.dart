import 'package:flutter/material.dart';
import 'package:cyra/features/chat/domain/chat_model.dart';

class SampleChats {
  static List<ChatModel> getChats() {
    return [
      ChatModel(
        id: 'user_1',
        contactName: 'Cyra Team',
        lastMessage: 'Welcome to Cyra Messaging!',
        timestamp: DateTime.now(),
        unreadCount: 1,
        isPinned: true,
        messageStatus: MessageStatus.delivered,
        isSentByMe: false,
        avatarColor: Colors.teal,
      ),
      ChatModel(
        id: 'user_2',
        contactName: 'Demo User',
        lastMessage: 'Hey! Are we still on for today?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 0,
        isPinned: false,
        messageStatus: MessageStatus.read,
        isSentByMe: true,
        avatarColor: Colors.blueAccent,
      ),
    ];
  }

  static List<ChatModel> getArchivedChats() {
    return [];
  }
}
