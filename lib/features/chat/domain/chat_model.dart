import 'package:flutter/material.dart';

enum MessageStatus { sent, delivered, read }

class ChatModel {
  final String id;
  final String contactName;
  final String? contactAvatar;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;
  final MessageStatus messageStatus;
  final bool isSentByMe;
  final Color? avatarColor;

  ChatModel({
    required this.id,
    required this.contactName,
    this.contactAvatar,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isArchived = false,
    this.messageStatus = MessageStatus.delivered,
    this.isSentByMe = true,
    this.avatarColor,
  });

  // Helper to format timestamp
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      // Today - show time
      final hour = timestamp.hour;
      final minute = timestamp.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'pm' : 'am';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week - show day name
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[timestamp.weekday - 1];
    } else {
      // Older - show date
      return '${timestamp.day}/${timestamp.month}/${timestamp.year.toString().substring(2)}';
    }
  }

  // Helper for status icon
  IconData get statusIcon {
    switch (messageStatus) {
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
    }
  }

  Color statusIconColor(bool isDark) {
    if (messageStatus == MessageStatus.read) {
      return isDark ? const Color(0xFF4DD0E1) : const Color(0xFF008080);
    }
    return isDark ? Colors.grey.shade400 : Colors.grey.shade600;
  }
}
