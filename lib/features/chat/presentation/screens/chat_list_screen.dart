import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cyra/core/services/auth_service.dart';
import 'package:cyra/features/chat/domain/chat_model.dart';
import 'package:cyra/features/chat/data/chat_repository.dart';
import 'package:cyra/features/chat/presentation/widgets/chat_list_item.dart';
import 'package:cyra/core/widgets/shimmer_chat_list.dart';
import 'package:cyra/features/chat/presentation/widgets/bottom_nav_bar.dart';
import 'package:cyra/features/chat/presentation/screens/chat_screen.dart';
import 'package:cyra/features/chat/presentation/screens/contacts_screen.dart';
import 'package:cyra/features/chat/presentation/screens/archived_chats_screen.dart';
import 'package:cyra/features/status/presentation/screens/status_screen.dart';
import 'package:cyra/features/profile/presentation/screens/settings_screen.dart';
import 'package:cyra/features/call/data/call_repository.dart';
import 'package:cyra/features/call/domain/call_model.dart';
import 'package:cyra/features/call/presentation/screens/voice_call_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _authService = AuthService();
  final _searchController = TextEditingController();
  late final ChatRepository _chatRepo;

  int _bottomNavIndex = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _chatRepo = ChatRepository(
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instance,
    );
    _listenForIncomingCalls();
  }

  void _listenForIncomingCalls() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final callRepo = CallRepository(firestore: FirebaseFirestore.instance);
    callRepo.getIncomingCalls(currentUser.uid).listen((calls) {
      if (calls.isNotEmpty && mounted) {
        final call = calls.first;
        _showIncomingCallDialog(call);
      }
    });
  }

  void _showIncomingCallDialog(CallModel call) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Incoming Call'),
        content: Text('Call from ${call.callerId}'), // Replace with actual name
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _declineCall(call.callId);
            },
            child: const Text('Decline'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _acceptCall(call);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _acceptCall(CallModel call) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          callId: call.callId,
          receiverId: call.callerId,
          isIncoming: true,
        ),
      ),
    );
  }

  void _declineCall(String callId) {
    final callRepo = CallRepository(firestore: FirebaseFirestore.instance);
    callRepo.endCall(callId);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (_bottomNavIndex != 0) {
      if (_bottomNavIndex == 1) {
        return Scaffold(
          extendBody: true,
          appBar: AppBar(title: Text(_getTabTitle())),
          body: const StatusScreen(),
          bottomNavigationBar: _buildBottomNav(),
        );
      }
      if (_bottomNavIndex == 3) {
        return Scaffold(
          extendBody: true,
          appBar: AppBar(title: Text(_getTabTitle())),
          body: const SettingsScreen(),
          bottomNavigationBar: _buildBottomNav(),
        );
      }
      return Scaffold(
        extendBody: true,
        appBar: AppBar(title: Text(_getTabTitle())),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getTabIcon(), size: 80, color: theme.colorScheme.primary.withAlpha(128)),
              const SizedBox(height: 16),
              Text('${_getTabTitle()} Coming Soon!', style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon!')));
          },
          backgroundColor: theme.colorScheme.primary,
          child: const Icon(Icons.message, color: Colors.white),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Cyra', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR Scanner coming soon!')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera coming soon!')));
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') _handleSignOut();
              if (value == 'settings') setState(() => _bottomNavIndex = 3);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Chat List
          Expanded(
            child: currentUser == null
                ? const Center(child: Text('Not signed in'))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .where('participants', arrayContains: currentUser.uid)
                        .orderBy('last_message_time', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const ShimmerChatList();
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No active chats. Start one!'));
                      }

                      var rawChats = snapshot.data!.docs.map((doc) {
                        return _buildChatModelFromDoc(doc.data() as Map<String, dynamic>, currentUser.uid);
                      }).toList();

                      if (_searchQuery.isNotEmpty) {
                        rawChats = rawChats.where((chat) {
                          return chat.contactName.toLowerCase().contains(_searchQuery) ||
                                 chat.lastMessage.toLowerCase().contains(_searchQuery);
                        }).toList();
                      }

                      final archivedChats = rawChats.where((c) => c.isArchived).toList();
                      final activeChats = rawChats.where((c) => !c.isArchived).toList();
                      
                      final pinnedChats = activeChats.where((c) => c.isPinned).toList();
                      final unpinnedChats = activeChats.where((c) => !c.isPinned).toList();

                      if (_searchQuery.isNotEmpty && rawChats.isEmpty) {
                        return const Center(child: Text('No matching chats found.'));
                      }

                      return ListView(
                        padding: const EdgeInsets.only(bottom: 140),
                        children: [
                          if (archivedChats.isNotEmpty && _searchQuery.isEmpty)
                            ListTile(
                              leading: const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Icon(Icons.archive_outlined),
                              ),
                              title: const Text('Archived', style: TextStyle(fontWeight: FontWeight.w600)),
                              trailing: Text('${archivedChats.length}', style: TextStyle(color: theme.colorScheme.primary)),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchivedChatsScreen()));
                              },
                            ),
                          
                          if (pinnedChats.isNotEmpty) ...[
                            ...pinnedChats.map((chat) => _buildDismissibleChat(chat, currentUser.uid)),
                            const Divider(height: 1),
                          ],
                          
                          ...unpinnedChats.map((chat) => _buildDismissibleChat(chat, currentUser.uid)),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactsScreen()));
        },
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.message, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      child: BottomNavBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) => setState(() => _bottomNavIndex = index),
      ),
    );
  }

  Widget _buildDismissibleChat(ChatModel chat, String uid) {
    return Dismissible(
      key: Key(chat.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Pin/Unpin
          await _chatRepo.pinChat(chat.id, uid, !chat.isPinned);
          return false;
        } else {
          // Swipe Left: Archive
          await _chatRepo.archiveChat(chat.id, uid, true);
          return false; // stream update will remove it from view
        }
      },
      background: Container(
        color: chat.isPinned ? Colors.grey : Colors.blue,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(chat.isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.green,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.archive, color: Colors.white),
      ),
      child: ChatListItem(
        chat: chat,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(chat: chat)));
        },
      ),
    );
  }

  String _getTabTitle() {
    switch (_bottomNavIndex) {
      case 0: return 'Chats';
      case 1: return 'Updates';
      case 2: return 'Communities';
      case 3: return 'Settings';
      default: return 'Cyra';
    }
  }

  IconData _getTabIcon() {
    switch (_bottomNavIndex) {
      case 0: return Icons.chat_bubble;
      case 1: return Icons.update;
      case 2: return Icons.groups;
      case 3: return Icons.settings;
      default: return Icons.chat_bubble;
    }
  }
}
