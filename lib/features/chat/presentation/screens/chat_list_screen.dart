import 'package:flutter/material.dart';
import 'package:cyra/core/services/auth_service.dart';
import 'package:cyra/features/chat/domain/chat_model.dart';
import 'package:cyra/features/chat/data/sample_chats.dart';
import 'package:cyra/features/chat/presentation/widgets/chat_list_item.dart';
import 'package:cyra/features/chat/presentation/widgets/chat_filter_chip.dart';
import 'package:cyra/features/chat/presentation/widgets/bottom_nav_bar.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _authService = AuthService();
  final _searchController = TextEditingController();

  int _selectedFilter = 0;
  int _bottomNavIndex = 0;
  bool _showArchived = false;
  List<ChatModel> _allChats = [];
  List<ChatModel> _archivedChats = [];
  List<ChatModel> _filteredChats = [];

  final List<String> _filters = ['All', 'Favourites', 'Groups', 'Project'];

  @override
  void initState() {
    super.initState();
    _loadChats();
    _searchController.addListener(_filterChats);
  }

  void _loadChats() {
    setState(() {
      _allChats = SampleChats.getChats();
      _archivedChats = SampleChats.getArchivedChats();
      _filteredChats = _allChats;
    });
  }

  void _filterChats() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredChats = _allChats.where((chat) {
        final nameMatch = chat.contactName.toLowerCase().contains(query);
        final messageMatch = chat.lastMessage.toLowerCase().contains(query);
        return nameMatch || messageMatch;
      }).toList();
    });
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

    // Show placeholder for other tabs
    if (_bottomNavIndex != 0) {
      return Scaffold(
        appBar: AppBar(title: Text(_getTabTitle())),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getTabIcon(),
                size: 80,
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                '${_getTabTitle()} Coming Soon!',
                style: theme.textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _bottomNavIndex,
          onTap: (index) => setState(() => _bottomNavIndex = index),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cyra',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR Scanner coming soon!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Camera coming soon!')),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _handleSignOut();
              }
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
                hintText: 'Ask Meta AI or Search',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF2C2C2C)
                    : Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Filter Chips
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                ...List.generate(_filters.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChatFilterChip(
                      label: _filters[index],
                      isSelected: _selectedFilter == index,
                      onTap: () => setState(() => _selectedFilter = index),
                    ),
                  );
                }),
                ChatFilterChip(
                  label: '+',
                  isSelected: false,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Add filter coming soon!')),
                    );
                  },
                  isAddButton: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Chat List
          Expanded(
            child: ListView(
              children: [
                // Archived Section
                if (_archivedChats.isNotEmpty)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _showArchived = !_showArchived);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.archive_outlined,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Text(
                                'Archived',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Text(
                              _archivedChats.length.toString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _showArchived
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Archived Chats (Expandable)
                if (_showArchived)
                  ..._archivedChats.map(
                    (chat) => ChatListItem(
                      chat: chat,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Opened chat with ${chat.contactName}',
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Pinned Chats
                ..._filteredChats
                    .where((chat) => chat.isPinned)
                    .map(
                      (chat) => ChatListItem(
                        chat: chat,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Opened chat with ${chat.contactName}',
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                // Regular Chats
                ..._filteredChats
                    .where((chat) => !chat.isPinned)
                    .map(
                      (chat) => ChatListItem(
                        chat: chat,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Opened chat with ${chat.contactName}',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New chat coming soon!')),
          );
        },
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.message, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) => setState(() => _bottomNavIndex = index),
      ),
    );
  }

  String _getTabTitle() {
    switch (_bottomNavIndex) {
      case 0:
        return 'Chats';
      case 1:
        return 'Updates';
      case 2:
        return 'Communities';
      case 3:
        return 'Calls';
      default:
        return 'Cyra';
    }
  }

  IconData _getTabIcon() {
    switch (_bottomNavIndex) {
      case 0:
        return Icons.chat_bubble;
      case 1:
        return Icons.update;
      case 2:
        return Icons.groups;
      case 3:
        return Icons.call;
      default:
        return Icons.chat_bubble;
    }
  }
}
