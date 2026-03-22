import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cyra/features/chat/domain/message_model.dart';
import 'package:uuid/uuid.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository(
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instance,
    ));

class ChatRepository {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final Uuid _uuid = const Uuid();

  ChatRepository({
    required this.firestore,
    required this.storage,
  });

  // Method to send a new message
  Future<void> sendMessage({
    required String receiverId,
    required String senderId,
    required String text,
    MessageType type = MessageType.text,
    bool isGroupChat = false,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
  }) async {
    try {
      final messageId = _uuid.v4();
      final message = MessageModel(
        messageId: messageId,
        senderId: senderId,
        receiverId: receiverId,
        text: text,
        type: type,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
        replyToId: replyToId,
        replyToText: replyToText,
        replyToSender: replyToSender,
      );

      final chatId = isGroupChat ? receiverId : getChatId(senderId, receiverId);

      // Save message to both users' chats collection
      await firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());

      // Update the recent chat info
      await firestore.collection('chats').doc(chatId).set({
        'chat_id': chatId,
        'participants': FieldValue.arrayUnion([senderId, receiverId]),
        'last_message': text,
        'last_message_time': DateTime.now(),
        'last_sender': senderId,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Create a entirely new group chat
  Future<void> createGroupChat({
    required String groupName,
    required List<String> participantIds,
    File? profilePic,
    required String creatorId,
  }) async {
    try {
      final groupId = _uuid.v4();
      String? groupIconUrl;

      // Ensure creator is in the participants list
      if (!participantIds.contains(creatorId)) {
        participantIds.add(creatorId);
      }

      // Add profile picture if provided
      if (profilePic != null) {
        groupIconUrl = await uploadImageToStorage(
          'group_icons/$groupId', 
          profilePic,
        );
      }

      // Create the group initial document
      await firestore.collection('chats').doc(groupId).set({
        'chat_id': groupId,
        'is_group': true,
        'group_name': groupName,
        'group_icon': groupIconUrl,
        'participants': participantIds,
        'admins': [creatorId],
        'last_message': 'Group created by You', // System message
        'last_message_time': DateTime.now(),
        'last_sender': creatorId,
      });
      
      // Let's also add an explicit system message inside the messages subcollection
      final messageId = _uuid.v4();
      final message = MessageModel(
        messageId: messageId,
        senderId: creatorId,
        receiverId: groupId,
        text: 'created this group.',
        type: MessageType.text, // Could be system in future
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );
      
      await firestore
          .collection('chats')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());
          
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  // Upload generic file to Firebase Storage
  Future<String> uploadFileToStorage(String childName, File file) async {
    try {
      Reference ref = storage.ref().child(childName).child(_uuid.v4());
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  // Upload image to Firebase Storage
  Future<String> uploadImageToStorage(String childName, File file) async {
    try {
      Reference ref = storage.ref().child(childName).child(_uuid.v4());
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Send an image message
  Future<void> sendImageMessage({
    required String receiverId,
    required String senderId,
    required File file,
    bool isGroupChat = false,
  }) async {
    try {
      final chatId = isGroupChat ? receiverId : getChatId(senderId, receiverId);
      
      // 1. Upload the image to storage
      final imageUrl = await uploadImageToStorage(
        'chat_images/$chatId', 
        file,
      );

      // 2. Create the message model with the image URL
      final messageId = _uuid.v4();
      final message = MessageModel(
        messageId: messageId,
        senderId: senderId,
        receiverId: receiverId,
        text: '📷 Photo', // For the 'last_message' preview
        imageUrl: imageUrl,
        type: MessageType.image,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );

      // 3. Save message to chats collection
      await firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());

      // 4. Update the recent chat info preview
      await firestore.collection('chats').doc(chatId).set({
        'chat_id': chatId,
        'participants': FieldValue.arrayUnion(isGroupChat ? [] : [senderId, receiverId]),
        'last_message': '📷 Photo',
        'last_message_time': DateTime.now(),
        'last_sender': senderId,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to send image message: $e');
    }
  }

  // Send a document message
  Future<void> sendDocumentMessage({
    required String receiverId,
    required String senderId,
    required File file,
    required String fileName,
    required String fileSize,
    bool isGroupChat = false,
  }) async {
    try {
      final chatId = isGroupChat ? receiverId : getChatId(senderId, receiverId);
      
      final documentUrl = await uploadFileToStorage(
        'chat_documents/$chatId', 
        file,
      );

      final messageId = _uuid.v4();
      final message = MessageModel(
        messageId: messageId,
        senderId: senderId,
        receiverId: receiverId,
        text: '📄 Document', 
        documentUrl: documentUrl,
        fileName: fileName,
        fileSize: fileSize,
        type: MessageType.document,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );

      await firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());

      await firestore.collection('chats').doc(chatId).set({
        'chat_id': chatId,
        'participants': FieldValue.arrayUnion(isGroupChat ? [] : [senderId, receiverId]),
        'last_message': '📄 Document',
        'last_message_time': DateTime.now(),
        'last_sender': senderId,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to send document message: $e');
    }
  }

  // Send an audio message
  Future<void> sendAudioMessage({
    required String receiverId,
    required String senderId,
    required File file,
    bool isGroupChat = false,
  }) async {
    try {
      final chatId = isGroupChat ? receiverId : getChatId(senderId, receiverId);
      
      final audioUrl = await uploadFileToStorage(
        'chat_audio/$chatId', 
        file,
      );

      final messageId = _uuid.v4();
      final message = MessageModel(
        messageId: messageId,
        senderId: senderId,
        receiverId: receiverId,
        text: '🎵 Audio', 
        audioUrl: audioUrl,
        type: MessageType.audio,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );

      await firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());

      await firestore.collection('chats').doc(chatId).set({
        'chat_id': chatId,
        'participants': FieldValue.arrayUnion(isGroupChat ? [] : [senderId, receiverId]),
        'last_message': '🎵 Audio',
        'last_message_time': DateTime.now(),
        'last_sender': senderId,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to send audio message: $e');
    }
  }

  // Stream of messages for a specific chat (with limit for performance)
  Stream<List<MessageModel>> getChatMessages(String receiverId, String senderId, {bool isGroupChat = false, int limit = 50}) {
    final chatId = isGroupChat ? receiverId : getChatId(senderId, receiverId);

    return firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MessageModel.fromMap(doc.data())).toList();
    });
  }

  // Fetch a single page of older messages (for pagination / lazy loading)
  Future<List<MessageModel>> getOlderMessages({
    required String chatId,
    required DocumentSnapshot lastDocument,
    int limit = 20,
  }) async {
    final snapshot = await firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .startAfterDocument(lastDocument)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => MessageModel.fromMap(doc.data())).toList();
  }

  // Consistent chat ID generation regardless of who initiates
  String getChatId(String user1Id, String user2Id) {
    List<String> ids = [user1Id, user2Id];
    ids.sort(); // Sort so the ID is always exactly the same between these two users
    return ids.join('_');
  }

  // Update typing status
  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping) async {
    try {
      await firestore.collection('chats').doc(chatId).set({
        'typing_$userId': isTyping,
      }, SetOptions(merge: true));
    } catch (e) {
      // Silently fail typing status updates to not disrupt user experience
      debugPrint('Error updating typing status: $e');
    }
  }

  // Stream of the chat document metadata (for typing status)
  Stream<DocumentSnapshot> getChatDocument(String chatId) {
    return firestore.collection('chats').doc(chatId).snapshots();
  }

  // ──────────── MESSAGE ACTIONS ────────────

  /// Toggle star on a message
  Future<void> toggleStarMessage(String chatId, String messageId, bool isStarred) async {
    await firestore
        .collection('chats').doc(chatId)
        .collection('messages').doc(messageId)
        .update({'isStarred': isStarred});
  }

  /// Add emoji reaction to a message
  Future<void> addReaction(String chatId, String messageId, String emoji, String userId) async {
    final docRef = firestore
        .collection('chats').doc(chatId)
        .collection('messages').doc(messageId);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    Map<String, dynamic> reactions = Map<String, dynamic>.from(data['reactions'] ?? {});

    List<String> users = List<String>.from(reactions[emoji] ?? []);
    if (users.contains(userId)) {
      users.remove(userId); // Toggle off
    } else {
      users.add(userId); // Toggle on
    }

    if (users.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = users;
    }

    await docRef.update({'reactions': reactions});
  }

  /// Delete message for me (soft delete)
  Future<void> deleteMessage(String chatId, String messageId) async {
    await firestore
        .collection('chats').doc(chatId)
        .collection('messages').doc(messageId)
        .update({'isDeleted': true, 'text': 'This message was deleted'});
  }

  /// Pin/unpin a chat
  Future<void> pinChat(String chatId, String userId, bool isPinned) async {
    await firestore.collection('chats').doc(chatId).update({'is_pinned_$userId': isPinned});
  }

  /// Archive/unarchive a chat
  Future<void> archiveChat(String chatId, String userId, bool isArchived) async {
    await firestore.collection('chats').doc(chatId).update({'is_archived_$userId': isArchived});
  }

  /// Clear chat history for a specific user (hides messages before this timestamp locally)
  Future<void> clearChat(String chatId, String userId) async {
    await firestore.collection('chats').doc(chatId).set({
      'cleared_at_$userId': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Forward a message to another chat
  Future<void> forwardMessage({
    required MessageModel originalMessage,
    required String targetChatId,
    required String senderId,
  }) async {
    final messageId = _uuid.v4();
    final forwarded = MessageModel(
      messageId: messageId,
      senderId: senderId,
      receiverId: targetChatId,
      text: originalMessage.text,
      imageUrl: originalMessage.imageUrl,
      audioUrl: originalMessage.audioUrl,
      documentUrl: originalMessage.documentUrl,
      fileName: originalMessage.fileName,
      fileSize: originalMessage.fileSize,
      type: originalMessage.type,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      isForwarded: true,
    );

    await firestore
        .collection('chats').doc(targetChatId)
        .collection('messages').doc(messageId)
        .set(forwarded.toMap());

    await firestore.collection('chats').doc(targetChatId).update({
      'last_message': originalMessage.type == MessageType.text
          ? originalMessage.text
          : '📎 Forwarded',
      'last_message_time': DateTime.now(),
      'last_sender': senderId,
    });
  }

  /// Search messages within a chat
  Future<List<MessageModel>> searchMessages(String chatId, String query) async {
    // Firestore doesn't support full-text search natively,
    // so we fetch recent messages and filter client-side
    final snapshot = await firestore
        .collection('chats').doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(200)
        .get();

    final lowerQuery = query.toLowerCase();
    return snapshot.docs
        .map((doc) => MessageModel.fromMap(doc.data()))
        .where((msg) => msg.text.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Get all starred messages for a user across all chats
  Stream<List<Map<String, dynamic>>> getStarredMessages(String userId) {
    return firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((chatSnapshot) async {
      List<Map<String, dynamic>> starredMessages = [];
      for (var chatDoc in chatSnapshot.docs) {
        final messagesSnapshot = await chatDoc.reference
            .collection('messages')
            .where('isStarred', isEqualTo: true)
            .get();
        for (var msgDoc in messagesSnapshot.docs) {
          starredMessages.add({
            'chatId': chatDoc.id,
            'message': MessageModel.fromMap(msgDoc.data()),
          });
        }
      }
      return starredMessages;
    });
  }

  /// Update user presence (online/offline)
  Future<void> updatePresence(String userId, bool isOnline) async {
    await firestore.collection('user_db').doc(userId).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}
