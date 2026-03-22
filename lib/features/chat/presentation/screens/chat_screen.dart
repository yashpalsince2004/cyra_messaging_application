import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cyra/features/chat/domain/chat_model.dart';
import 'package:cyra/features/chat/domain/message_model.dart';
import 'package:cyra/core/services/ai_service.dart';
import 'package:cyra/features/chat/data/chat_repository.dart';
import 'package:cyra/features/chat/presentation/widgets/message_bubble.dart';
import 'package:cyra/features/chat/presentation/screens/group_info_screen.dart';
import 'package:cyra/features/chat/presentation/widgets/ai_enhance_sheet.dart';
import 'package:cyra/features/call/presentation/screens/voice_call_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final ChatModel chat;

  const ChatScreen({super.key, required this.chat});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;
  late final String _chatId;

  // Audio Recording states
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  // Reply state
  MessageModel? _replyingTo;

  // Scroll-to-bottom FAB
  bool _showScrollToBottom = false;

  // Search
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<MessageModel> _searchResults = [];

  late Stream<List<MessageModel>> _messagesStream;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final chatRepo = ref.read(chatRepositoryProvider);
      _chatId = widget.chat.isGroup
          ? widget.chat.id
          : chatRepo.getChatId(currentUser.uid, widget.chat.id);
      _messagesStream = chatRepo.getChatMessages(
        widget.chat.id,
        currentUser.uid,
        isGroupChat: widget.chat.isGroup,
      );
    } else {
      _chatId = '';
      _messagesStream = const Stream.empty();
    }
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final showFab =
        _scrollController.hasClients && _scrollController.offset > 200;
    if (showFab != _showScrollToBottom) {
      setState(() => _showScrollToBottom = showFab);
    }
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) _setTyping(true);
    _typingTimer?.cancel();
    if (text.isEmpty) {
      _setTyping(false);
    } else {
      _typingTimer = Timer(
        const Duration(milliseconds: 1500),
        () => _setTyping(false),
      );
    }
  }

  void _setTyping(bool typing) {
    if (_isTyping == typing) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    setState(() => _isTyping = typing);
    ref
        .read(chatRepositoryProvider)
        .updateTypingStatus(_chatId, currentUser.uid, typing);
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final chatRepo = ref.read(chatRepositoryProvider);
    _messageController.clear();

    try {
      await chatRepo.sendMessage(
        receiverId: widget.chat.id,
        senderId: currentUser.uid,
        text: text,
        replyToId: _replyingTo?.messageId,
        replyToText: _replyingTo?.text,
        replyToSender: _replyingTo?.senderId == currentUser.uid
            ? 'You'
            : widget.chat.contactName,
      );
      setState(() => _replyingTo = null);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  void _sendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uploading image...')));
    final chatRepo = ref.read(chatRepositoryProvider);
    try {
      await chatRepo.sendImageMessage(
        receiverId: widget.chat.id,
        senderId: currentUser.uid,
        file: File(image.path),
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _sendDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final fileSize =
          '${(result.files.single.size / 1024).toStringAsFixed(1)} KB';
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploading document...')));
      final chatRepo = ref.read(chatRepositoryProvider);
      try {
        await chatRepo.sendDocumentMessage(
          receiverId: widget.chat.id,
          senderId: currentUser.uid,
          file: file,
          fileName: fileName,
          fileSize: fileSize,
        );
        _scrollToBottom();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        final Directory appDocumentsDir =
            await getApplicationDocumentsDirectory();
        final recordingPath =
            '${appDocumentsDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: recordingPath,
        );
        setState(() => _isRecording = true);
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required.')),
          );
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;
        final chatRepo = ref.read(chatRepositoryProvider);
        await chatRepo.sendAudioMessage(
          receiverId: widget.chat.id,
          senderId: currentUser.uid,
          file: File(path),
        );
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 150,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAttachmentIcon(
                icon: Icons.insert_drive_file,
                color: Colors.indigo,
                title: 'Document',
                onTap: () {
                  Navigator.pop(context);
                  _sendDocument();
                },
              ),
              _buildAttachmentIcon(
                icon: Icons.image,
                color: Colors.purple,
                title: 'Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _sendImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTranslationMenu() {
    final languages = [
      {'name': 'English', 'flag': '🇺🇸'},
      {'name': 'Hindi', 'flag': '🇮🇳'},
      {'name': 'Spanish', 'flag': '🇪🇸'},
      {'name': 'French', 'flag': '🇫🇷'},
      {'name': 'German', 'flag': '🇩🇪'},
      {'name': 'Japanese', 'flag': '🇯🇵'},
      {'name': 'Chinese', 'flag': '🇨🇳'},
      {'name': 'Arabic', 'flag': '🇸🇦'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Translate Chat',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    return ListTile(
                      leading: Text(
                        lang['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(lang['name']!),
                      onTap: () {
                        Navigator.pop(context);
                        _applyTranslation(lang['name']!);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyTranslation(String language) async {
    // We will handle translation locally for the visible batch in build
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Translating to $language...')));
    setState(() {
      _activeTranslationLanguage = language;
    });
  }

  String? _activeTranslationLanguage;
  bool _isTranslating = false;

  // Translation cache: messageId -> translated text
  final Map<String, String> _translationCache = {};

  void _triggerBatchTranslation(
    List<MessageModel> messages,
    String language,
  ) async {
    // Skip messages already translated
    final untranslated = messages
        .where(
          (m) =>
              m.type == MessageType.text &&
              !_translationCache.containsKey(m.messageId),
        )
        .toList();

    if (untranslated.isEmpty) {
      // All messages already cached — just make sure UI reflects it
      if (_isTranslating) {
        setState(() => _isTranslating = false);
      }
      return;
    }

    // Mark translating immediately (no setState here — called via postFrameCallback)
    _isTranslating = true;

    try {
      final aiService = ref.read(aiServiceProvider);
      final texts = untranslated.map((m) => m.text).toList();
      final translatedTexts = await aiService.translateBatch(texts, language);

      if (mounted) {
        setState(() {
          for (int i = 0; i < untranslated.length; i++) {
            _translationCache[untranslated[i].messageId] = translatedTexts[i];
          }
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Translation failed: $e')));
        setState(() => _isTranslating = false);
      }
    }
  }

  void _enhanceMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final aiService = ref.read(aiServiceProvider);

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          AiEnhanceSheet(originalText: text, aiService: aiService),
    );

    if (result != null && mounted) {
      _messageController.text = result;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    }
  }

  Widget _buildAttachmentIcon({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final chatRepo = ref.read(chatRepositoryProvider);
    final results = await chatRepo.searchMessages(_chatId, query);
    setState(() => _searchResults = results);
  }

  void _clearChat() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Clear all messages in this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final chatRepo = ref.read(chatRepositoryProvider);
        await chatRepo.clearChat(_chatId, currentUser.uid);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat cleared')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to clear chat: $e')));
      }
    }
  }

  void _startVoiceCall() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // For now, assume we're calling the other participant
    // In a group chat, this would need to be handled differently
    final receiverId = widget.chat.isGroup ? '' : widget.chat.id;

    if (receiverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot start call in group chat yet')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          callId: '', // Will be generated
          receiverId: receiverId,
          isIncoming: false,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _typingTimer?.cancel();
    _setTyping(false);
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;
    final chatRepo = ref.watch(chatRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search messages...',
                  border: InputBorder.none,
                ),
                onChanged: _performSearch,
              )
            : GestureDetector(
                onTap: () {
                  if (widget.chat.isGroup) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            GroupInfoScreen(chat: widget.chat),
                      ),
                    );
                  }
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Text(
                        widget.chat.contactName.isNotEmpty
                            ? widget.chat.contactName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.chat.contactName,
                            style: const TextStyle(fontSize: 16),
                          ),
                          StreamBuilder<DocumentSnapshot>(
                            stream: chatRepo.getChatDocument(_chatId),
                            builder: (context, snapshot) {
                              bool isOtherUserTyping = false;
                              if (snapshot.hasData && snapshot.data!.exists) {
                                final data =
                                    snapshot.data!.data()
                                        as Map<String, dynamic>;
                                isOtherUserTyping =
                                    data['typing_${widget.chat.id}'] ?? false;
                              }
                              return Text(
                                isOtherUserTyping ? 'typing...' : 'Online',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOtherUserTyping
                                      ? theme.colorScheme.primary
                                      : (isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600]),
                                  fontWeight: isOtherUserTyping
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
          ),
          if (!_isSearching) ...[
            IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: _startVoiceCall,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'translate') {
                  _showTranslationMenu();
                } else if (value == 'clear') {
                  _clearChat();
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$value coming soon')));
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'translate',
                  child: Text('Translate Chat'),
                ),
                const PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
                const PopupMenuItem(
                  value: 'export',
                  child: Text('Export Chat'),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Text('Chat Settings'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search results bar
              if (_isSearching && _searchResults.isNotEmpty)
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: theme.colorScheme.primaryContainer,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_searchResults.length} results found',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontSize: 13,
                    ),
                  ),
                ),

              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: chatRepo.getChatDocument(_chatId),
                  builder: (context, chatSnapshot) {
                    Timestamp? clearedAt;
                    if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                      final data =
                          chatSnapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null && currentUser != null) {
                        clearedAt =
                            data['cleared_at_${currentUser.uid}'] as Timestamp?;
                      }
                    }

                    return StreamBuilder<List<MessageModel>>(
                      stream: _messagesStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        var messages = snapshot.data ?? [];

                        // Filter out messages before the cleared_at timestamp
                        if (clearedAt != null) {
                          final clearedDate = clearedAt.toDate();
                          messages = messages
                              .where((m) => m.timestamp.isAfter(clearedDate))
                              .toList();
                        }

                        if (messages.isEmpty) {
                          return const Center(
                            child: Text('Start the conversation!'),
                          );
                        }

                        // Trigger batch translation after this frame completes
                        if (_activeTranslationLanguage != null &&
                            !_isTranslating) {
                          SchedulerBinding.instance.addPostFrameCallback((_) {
                            if (mounted &&
                                _activeTranslationLanguage != null &&
                                !_isTranslating) {
                              _triggerBatchTranslation(
                                messages,
                                _activeTranslationLanguage!,
                              );
                            }
                          });
                        }

                        return Column(
                          children: [
                            // Translation active banner
                            if (_activeTranslationLanguage != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                color: theme.colorScheme.tertiaryContainer,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.translate,
                                      size: 16,
                                      color:
                                          theme.colorScheme.onTertiaryContainer,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _isTranslating
                                            ? 'Translating to $_activeTranslationLanguage...'
                                            : 'Translated to $_activeTranslationLanguage',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme
                                              .colorScheme
                                              .onTertiaryContainer,
                                        ),
                                      ),
                                    ),
                                    if (_isTranslating)
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: theme
                                              .colorScheme
                                              .onTertiaryContainer,
                                        ),
                                      )
                                    else
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          _activeTranslationLanguage = null;
                                          _translationCache.clear();
                                        }),
                                        child: Icon(
                                          Icons.close,
                                          size: 18,
                                          color: theme
                                              .colorScheme
                                              .onTertiaryContainer,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                            // Message list
                            Expanded(
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                reverse: true,
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final isMe =
                                      message.senderId == currentUser?.uid;

                                  return Dismissible(
                                    key: Key(message.messageId),
                                    direction: DismissDirection.startToEnd,
                                    confirmDismiss: (_) async {
                                      setState(() => _replyingTo = message);
                                      return false;
                                    },
                                    background: Container(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 20),
                                      child: const Icon(
                                        Icons.reply,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    child: MessageBubble(
                                      message: message,
                                      isMe: isMe,
                                      translatedText:
                                          _translationCache[message.messageId],
                                      isTranslationActive:
                                          _activeTranslationLanguage != null,
                                      onReply: () =>
                                          setState(() => _replyingTo = message),
                                      onStar: () => chatRepo.toggleStarMessage(
                                        _chatId,
                                        message.messageId,
                                        !message.isStarred,
                                      ),
                                      onDelete: () => chatRepo.deleteMessage(
                                        _chatId,
                                        message.messageId,
                                      ),
                                      onForward: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Forward coming soon',
                                            ),
                                          ),
                                        );
                                      },
                                      onReaction: (emoji) =>
                                          chatRepo.addReaction(
                                            _chatId,
                                            message.messageId,
                                            emoji,
                                            currentUser!.uid,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // Chat Input Area
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // AI Enhance Button
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _messageController,
                        builder: (context, value, child) {
                          if (value.text.trim().isNotEmpty) {
                            return Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 8.0,
                                  right: 48,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: _enhanceMessage,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          theme.colorScheme.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: theme.colorScheme.tertiary
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          size: 14,
                                          color: theme
                                              .colorScheme
                                              .onTertiaryContainer,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '✨ AI Enhance',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: theme
                                                .colorScheme
                                                .onTertiaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                      _isRecording
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.mic,
                                  color: Colors.red,
                                  size: 28,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Recording...',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.red,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _stopRecordingAndSend,
                                  child: CircleAvatar(
                                    backgroundColor: theme.colorScheme.primary,
                                    radius: 24,
                                    child: const Icon(
                                      Icons.send,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: _showAttachmentMenu,
                                  color: theme.colorScheme.primary,
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    decoration: InputDecoration(
                                      hintText: 'Message',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? const Color(0xFF2C2C2C)
                                          : Colors.grey[200],
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                    ),
                                    onChanged: _onTextChanged,
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _messageController,
                                  builder: (context, value, child) {
                                    bool hasText = value.text.trim().isNotEmpty;
                                    if (hasText) {
                                      return GestureDetector(
                                        onTap: _sendMessage,
                                        child: CircleAvatar(
                                          backgroundColor:
                                              theme.colorScheme.primary,
                                          radius: 24,
                                          child: const Icon(
                                            Icons.send,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      );
                                    } else {
                                      return GestureDetector(
                                        onLongPress: _startRecording,
                                        onLongPressUp: _stopRecordingAndSend,
                                        child: CircleAvatar(
                                          backgroundColor:
                                              theme.colorScheme.primary,
                                          radius: 24,
                                          child: const Icon(
                                            Icons.mic,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Scroll to bottom FAB
          if (_showScrollToBottom)
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: _scrollToBottom,
                backgroundColor: isDark
                    ? const Color(0xFF2C2C2C)
                    : Colors.white,
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
