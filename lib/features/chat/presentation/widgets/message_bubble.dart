import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cyra/features/chat/domain/message_model.dart';
import 'package:cyra/features/chat/presentation/widgets/audio_message_player.dart';
import 'package:cyra/features/chat/presentation/widgets/document_message_widget.dart';
import 'package:cyra/features/chat/presentation/screens/image_viewer_screen.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onStar;
  final VoidCallback? onDelete;
  final VoidCallback? onForward;
  final Function(String emoji)? onReaction;
  final String? translatedText;
  final bool isTranslationActive;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onReply,
    this.onStar,
    this.onDelete,
    this.onForward,
    this.onReaction,
    this.translatedText,
    this.isTranslationActive = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showOriginal = false;

  static const List<String> reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reaction row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: reactionEmojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onReaction?.call(emoji);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () { Navigator.pop(ctx); widget.onReply?.call(); },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.message.text));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () { Navigator.pop(ctx); widget.onForward?.call(); },
            ),
            ListTile(
              leading: Icon(widget.message.isStarred ? Icons.star : Icons.star_border),
              title: Text(widget.message.isStarred ? 'Unstar' : 'Star'),
              onTap: () { Navigator.pop(ctx); widget.onStar?.call(); },
            ),
            if (widget.isMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(ctx); widget.onDelete?.call(); },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Determine the display text: translated or original
  String get _displayText {
    if (widget.isTranslationActive && widget.translatedText != null && !_showOriginal) {
      return widget.translatedText!;
    }
    return widget.message.text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeString = DateFormat('HH:mm').format(widget.message.timestamp);
    final isMe = widget.isMe;
    final message = widget.message;

    // Deleted message
    if (message.isDeleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text('This message was deleted',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[500], fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: EdgeInsets.only(
            bottom: 8,
            left: isMe ? 50 : 0,
            right: isMe ? 0 : 50,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Main bubble
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe
                      ? theme.colorScheme.primary
                      : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 20 : 12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Forwarded label
                    if (message.isForwarded)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.forward, size: 14,
                              color: isMe ? Colors.white70 : Colors.grey),
                            const SizedBox(width: 4),
                            Text('Forwarded',
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic,
                                color: isMe ? Colors.white70 : Colors.grey)),
                          ],
                        ),
                      ),

                    // Reply container
                    if (message.replyToText != null && message.replyToText!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withAlpha(30)
                              : theme.colorScheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.replyToSender ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message.replyToText!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isMe ? Colors.white70 : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Content
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        // Image
                        if (message.type == MessageType.image && message.imageUrl != null)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ImageViewerScreen(
                                    imageUrl: message.imageUrl!,
                                    heroTag: message.messageId,
                                    senderName: isMe ? 'You' : 'Contact',
                                    timeString: timeString,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              constraints: BoxConstraints(
                                maxHeight: 250,
                                maxWidth: MediaQuery.of(context).size.width * 0.65,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Hero(
                                  tag: message.messageId,
                                  child: CachedNetworkImage(
                                    imageUrl: message.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      height: 150, width: 150,
                                      color: isDark ? const Color(0xFF3C3C3C) : Colors.grey[300],
                                      child: const Center(child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (context, url, error) => const Icon(Icons.error),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Audio
                        if (message.type == MessageType.audio && message.audioUrl != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: AudioMessagePlayer(audioUrl: message.audioUrl!, isMe: isMe),
                          ),

                        // Document
                        if (message.type == MessageType.document && message.documentUrl != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: DocumentMessageWidget(
                              fileName: message.fileName ?? 'Document',
                              fileSize: message.fileSize ?? 'Unknown size',
                              documentUrl: message.documentUrl!,
                              isMe: isMe,
                            ),
                          ),

                        // Text (uses _displayText to show translated or original)
                        if (message.type == MessageType.text ||
                            (message.text.isNotEmpty && message.text != '📷 Photo' && message.text != '🎵 Audio' && message.text != '📄 Document'))
                          Padding(
                            padding: const EdgeInsets.only(right: 8, bottom: 2),
                            child: Text(
                              _displayText,
                              style: TextStyle(
                                fontSize: 15,
                                color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ),

                        // Meta (time + status + star)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (message.isStarred)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.star, size: 12,
                                  color: isMe ? Colors.white70 : Colors.amber),
                              ),
                            Text(
                              timeString,
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe ? Colors.white.withAlpha(180)
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.status == MessageStatus.read
                                    ? Icons.done_all
                                    : (message.status == MessageStatus.delivered
                                        ? Icons.done_all : Icons.check),
                                size: 14,
                                color: message.status == MessageStatus.read
                                    ? Colors.blue[300] : Colors.white.withAlpha(180),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),

                    // "Show Original" / "Show Translation" toggle
                    if (widget.isTranslationActive && widget.translatedText != null)
                      GestureDetector(
                        onTap: () => setState(() => _showOriginal = !_showOriginal),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.translate,
                                size: 12,
                                color: isMe ? Colors.white70 : theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showOriginal ? 'Show Translation' : 'Show Original',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isMe ? Colors.white70 : theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Reactions display
              if (message.reactions.isNotEmpty)
                Transform.translate(
                  offset: const Offset(0, -4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3C3C3C) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: message.reactions.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text('${entry.key} ${entry.value.length}',
                            style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
