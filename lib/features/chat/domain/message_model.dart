import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, audio, video, document }

enum MessageStatus { sent, delivered, read }

class MessageModel {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String text;
  final String? imageUrl;
  final String? audioUrl;
  final String? documentUrl;
  final String? fileName;
  final String? fileSize;
  final MessageType type;
  final DateTime timestamp;
  final MessageStatus status;

  // AI Translation fields
  final String? originalText;
  final String? translatedText;
  final String? translatedLanguage;

  // Reply fields
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;

  // Reactions: emoji -> list of user IDs
  final Map<String, List<String>> reactions;

  // Star & Forward & Delete
  final bool isStarred;
  final bool isForwarded;
  final bool isDeleted;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.imageUrl,
    this.audioUrl,
    this.documentUrl,
    this.fileName,
    this.fileSize,
    required this.type,
    required this.timestamp,
    required this.status,
    this.originalText,
    this.translatedText,
    this.translatedLanguage,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.reactions = const {},
    this.isStarred = false,
    this.isForwarded = false,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'documentUrl': documentUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'type': type.name,
      'timestamp': timestamp,
      'status': status.name,
      'originalText': originalText,
      'translatedText': translatedText,
      'translatedLanguage': translatedLanguage,
      'replyToId': replyToId,
      'replyToText': replyToText,
      'replyToSender': replyToSender,
      'reactions': reactions.map((k, v) => MapEntry(k, v)),
      'isStarred': isStarred,
      'isForwarded': isForwarded,
      'isDeleted': isDeleted,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    // Parse reactions map
    Map<String, List<String>> parsedReactions = {};
    if (map['reactions'] != null && map['reactions'] is Map) {
      (map['reactions'] as Map).forEach((key, value) {
        parsedReactions[key.toString()] = List<String>.from(value ?? []);
      });
    }

    return MessageModel(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      text: map['text'] ?? '',
      imageUrl: map['imageUrl'],
      audioUrl: map['audioUrl'],
      documentUrl: map['documentUrl'],
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      type: MessageType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      originalText: map['originalText'],
      translatedText: map['translatedText'],
      translatedLanguage: map['translatedLanguage'],
      replyToId: map['replyToId'],
      replyToText: map['replyToText'],
      replyToSender: map['replyToSender'],
      reactions: parsedReactions,
      isStarred: map['isStarred'] ?? false,
      isForwarded: map['isForwarded'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  /// Create a copy with modifications
  MessageModel copyWith({
    String? text,
    MessageStatus? status,
    bool? isStarred,
    bool? isDeleted,
    Map<String, List<String>>? reactions,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
    String? originalText,
    String? translatedText,
    String? translatedLanguage,
  }) {
    return MessageModel(
      messageId: messageId,
      senderId: senderId,
      receiverId: receiverId,
      text: text ?? this.text,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      documentUrl: documentUrl,
      fileName: fileName,
      fileSize: fileSize,
      type: type,
      timestamp: timestamp,
      status: status ?? this.status,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      translatedLanguage: translatedLanguage ?? this.translatedLanguage,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      replyToSender: replyToSender ?? this.replyToSender,
      reactions: reactions ?? this.reactions,
      isStarred: isStarred ?? this.isStarred,
      isForwarded: isForwarded,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
