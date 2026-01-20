import 'package:flutter/material.dart';
import 'package:cyra/features/chat/domain/chat_model.dart';

class ChatListItem extends StatelessWidget {
  final ChatModel chat;
  final VoidCallback? onTap;

  const ChatListItem({super.key, required this.chat, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: chat.avatarColor ?? theme.colorScheme.primary,
                child: chat.contactAvatar != null
                    ? ClipOval(
                        child: Image.network(
                          chat.contactAvatar!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildInitials();
                          },
                        ),
                      )
                    : _buildInitials(),
              ),

              const SizedBox(width: 12),

              // Chat info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.contactName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: chat.unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          chat.formattedTime,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: chat.unreadCount > 0
                                ? theme.colorScheme.primary
                                : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        // Message status icon (for sent messages)
                        if (chat.isSentByMe) ...[
                          Icon(
                            chat.statusIcon,
                            size: 16,
                            color: chat.statusIconColor(isDark),
                          ),
                          const SizedBox(width: 4),
                        ],

                        // Last message
                        Expanded(
                          child: Text(
                            chat.lastMessage,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                              fontWeight: chat.unreadCount > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Unread badge
                        if (chat.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              chat.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],

                        // Pin indicator
                        if (chat.isPinned && chat.unreadCount == 0) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.push_pin,
                            size: 16,
                            color: isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitials() {
    final initials = chat.contactName.isNotEmpty
        ? chat.contactName
              .split(' ')
              .take(2)
              .map((e) => e[0])
              .join()
              .toUpperCase()
        : '?';

    return Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
