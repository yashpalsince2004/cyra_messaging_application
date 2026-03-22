import 'package:flutter/material.dart';

class DocumentMessageWidget extends StatelessWidget {
  final String fileName;
  final String fileSize;
  final String documentUrl;
  final bool isMe;

  const DocumentMessageWidget({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.documentUrl,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final bgColor = isMe ? Colors.white.withAlpha(50) : (isDark ? Colors.black26 : Colors.grey[200]);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, color: color, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  fileSize,
                  style: TextStyle(color: color.withAlpha(180), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
