import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cyra/features/chat/domain/chat_model.dart';
import 'package:cyra/features/auth/domain/user_model.dart';

class GroupInfoScreen extends StatefulWidget {
  final ChatModel chat;

  const GroupInfoScreen({super.key, required this.chat});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isLoading = true;
  List<UserModel> _participants = [];
  List<String> _adminIds = [];
  
  // Realtime subscription holder
  late Stream<DocumentSnapshot> _groupStream;

  @override
  void initState() {
    super.initState();
    _groupStream = FirebaseFirestore.instance.collection('chats').doc(widget.chat.id).snapshots();
    _fetchParticipants();
  }

  Future<void> _fetchParticipants() async {
    try {
      final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chat.id).get();
      if (!chatDoc.exists) return;

      final data = chatDoc.data()!;
      final participantIds = List<String>.from(data['participants'] ?? []);
      _adminIds = List<String>.from(data['admins'] ?? []);

      if (participantIds.isEmpty) return;

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('user_db')
          .where('user_id', whereIn: participantIds)
          .get();

      final users = usersSnapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
      
      if (mounted) {
        setState(() {
          _participants = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load participants: $e')),
        );
      }
    }
  }

  void _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group?'),
        content: Text('Are you sure you want to leave ${widget.chat.contactName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && currentUserId != null) {
      try {
        await FirebaseFirestore.instance.collection('chats').doc(widget.chat.id).update({
          'participants': FieldValue.arrayRemove([currentUserId]),
          'admins': FieldValue.arrayRemove([currentUserId]),
        });
        
        // Return to home
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to leave group: $e')),
          );
        }
      }
    }
  }

  void _showAdminActions(BuildContext context, UserModel user, bool isTargetAdmin) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.message),
              title: Text('Message ${user.name}'),
              onTap: () {
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: Text(isTargetAdmin ? 'Dismiss as admin' : 'Make group admin'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  if (isTargetAdmin) {
                     await FirebaseFirestore.instance.collection('chats').doc(widget.chat.id).update({
                       'admins': FieldValue.arrayRemove([user.uid])
                     });
                     _adminIds.remove(user.uid);
                  } else {
                     await FirebaseFirestore.instance.collection('chats').doc(widget.chat.id).update({
                       'admins': FieldValue.arrayUnion([user.uid])
                     });
                     _adminIds.add(user.uid);
                  }
                  if (mounted) setState(() {});
                } catch (e) {
                   if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.red),
              title: Text('Remove ${user.name}', style: const TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                   await FirebaseFirestore.instance.collection('chats').doc(widget.chat.id).update({
                     'participants': FieldValue.arrayRemove([user.uid]),
                     'admins': FieldValue.arrayRemove([user.uid]),
                   });
                   _participants.removeWhere((p) => p.uid == user.uid);
                   _adminIds.remove(user.uid);
                   if (mounted) setState(() {});
                } catch (e) {
                   if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: _groupStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text('Group not found'));
          }

          final groupName = data['group_name'] ?? 'Group';
          final groupIcon = data['group_icon'];
          final participantCount = (data['participants'] as List?)?.length ?? 0;

          return CustomScrollView(
            slivers: [
              // Animated App Bar
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  maxHeight: 300,
                  minHeight: kToolbarHeight + MediaQuery.of(context).padding.top,
                  groupName: groupName,
                  groupIcon: groupIcon,
                ),
                pinned: true,
              ),

              // Group Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionCol(Icons.call, 'Audio', theme),
                      _buildActionCol(Icons.videocam, 'Video', theme),
                      _buildActionCol(Icons.search, 'Search', theme),
                    ],
                  ),
                ),
              ),

              // Participants List
              SliverToBoxAdapter(
                child: Container(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          '$participantCount participants',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        ..._participants.map((user) {
                          final isAdmin = _adminIds.contains(user.uid);
                          final isMe = user.uid == currentUserId;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.secondaryContainer,
                              child: Text(
                                user.name[0].toUpperCase(),
                                style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                              ),
                            ),
                            title: Text(isMe ? 'You' : user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(user.phoneNo),
                            trailing: isAdmin 
                              ? Text('Group Admin', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12))
                              : null,
                            onTap: () {
                              if (!isMe && _adminIds.contains(currentUserId)) {
                                _showAdminActions(context, user, isAdmin);
                              }
                            },
                          );
                        }),
                        
                      // Add Member button (for admins)
                      if (_adminIds.contains(currentUserId))
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            child: const Icon(Icons.person_add, color: Colors.white),
                          ),
                          title: const Text('Add members', style: TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add members coming soon')));
                          },
                        ),
                        
                      const Divider(height: 1),
                      
                      // Leave Group button
                      ListTile(
                        leading: const Icon(Icons.exit_to_app, color: Colors.red),
                        title: const Text('Leave group', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        onTap: _leaveGroup,
                      ),
                      const Divider(height: 1),
                      
                      const ListTile(
                        leading: Icon(Icons.thumb_down, color: Colors.red),
                        title: Text('Report group', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildActionCol(IconData icon, String label, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 28),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double maxHeight;
  final double minHeight;
  final String groupName;
  final String? groupIcon;

  _SliverAppBarDelegate({
    required this.maxHeight,
    required this.minHeight,
    required this.groupName,
    this.groupIcon,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = shrinkOffset / maxExtent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image / Avatar
          Opacity(
            opacity: 1 - progress,
            child: Container(
              color: isDark ? Colors.grey[900] : Colors.grey[200],
              child: groupIcon != null 
                  ? Image.network(groupIcon!, fit: BoxFit.cover)
                  : Icon(Icons.group, size: 100, color: isDark ? Colors.grey[800] : Colors.grey[400]),
            ),
          ),
          
          // Gradient for text readability
          if (groupIcon != null)
            Opacity(
              opacity: 1 - progress,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent, Colors.black87],
                  ),
                ),
              ),
            ),

          // App bar layer (Back button & constraints)
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            height: kToolbarHeight,
            child: Row(
              children: [
                const BackButton(color: Colors.white),
                const Spacer(),
                IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
              ],
            ),
          ),

          // Group Name
          Positioned(
            bottom: 16.0 + (progress * 16.0), // Moves up slightly as it shrinks
            left: 16.0 + (progress * 32.0), // Moves right to align with back button
            right: 16.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  groupName,
                  style: TextStyle(
                    fontSize: 24 - (progress * 4), // Shrinks from 24 to 20
                    fontWeight: FontWeight.bold,
                    color: groupIcon != null || progress == 1 ? Colors.white : (isDark ? Colors.white : Colors.black),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (progress < 0.5)
                  Text(
                    'Group',
                    style: TextStyle(
                      color: groupIcon != null ? Colors.white70 : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        groupName != oldDelegate.groupName ||
        groupIcon != oldDelegate.groupIcon;
  }
}
