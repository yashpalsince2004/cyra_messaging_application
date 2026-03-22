import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cyra/core/services/auth_service.dart';
import 'package:cyra/features/auth/domain/user_model.dart';
import 'package:cyra/features/profile/presentation/screens/profile_screen.dart';
import 'package:cyra/features/chat/presentation/screens/starred_messages_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _authService = AuthService();
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _firestore.collection('user_db').doc(uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _user = UserModel.fromMap(doc.data()!);
        _isLoading = false;
      });
    }
  }

  Future<void> _updateField(String field, dynamic value) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('user_db').doc(uid).update({field: value});
    _loadUser();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView(
      children: [
        // Profile Header
        InkWell(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            _loadUser();
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  backgroundImage: _user?.photoUrl != null ? CachedNetworkImageProvider(_user!.photoUrl!) : null,
                  child: _user?.photoUrl == null
                      ? Icon(Icons.person, size: 32, color: isDark ? Colors.grey[600] : Colors.grey[400])
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_user?.name ?? 'User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_user?.about ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    ],
                  ),
                ),
                Icon(Icons.qr_code, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        _buildSection(icon: Icons.key, iconColor: theme.colorScheme.primary, title: 'Account', subtitle: 'Security, change number, delete account', onTap: () {}),

        _buildSection(icon: Icons.lock, iconColor: theme.colorScheme.primary, title: 'Privacy', subtitle: 'Last seen, profile photo, read receipts', onTap: () => _showPrivacySheet(context)),

        _buildSection(icon: Icons.star, iconColor: Colors.amber, title: 'Starred Messages', subtitle: 'View your bookmarked messages', onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const StarredMessagesScreen()));
        }),

        _buildSection(icon: Icons.chat, iconColor: Colors.green, title: 'Chats', subtitle: 'Theme, wallpapers, chat history', onTap: () {}),

        _buildSection(icon: Icons.notifications, iconColor: Colors.red, title: 'Notifications', subtitle: 'Message, group & call tones', onTap: () {}),

        _buildSection(icon: Icons.data_usage, iconColor: Colors.teal, title: 'Storage and Data', subtitle: 'Network usage, auto-download', onTap: () {}),

        _buildSection(icon: Icons.language, iconColor: Colors.purple, title: 'App Language', subtitle: 'English (device\'s language)', onTap: () {}),

        _buildSection(icon: Icons.help_outline, iconColor: Colors.blue, title: 'Help', subtitle: 'Help centre, contact us, privacy policy', onTap: () {}),

        _buildSection(icon: Icons.group, iconColor: Colors.green, title: 'Invite a friend', subtitle: '', onTap: () {}),

        const Divider(),

        // Sign Out
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sign Out?'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out', style: TextStyle(color: Colors.red))),
                ],
              ),
            );
            if (confirmed == true) await _authService.signOut();
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSection({required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(fontSize: 13)) : null,
      onTap: onTap,
    );
  }

  void _showPrivacySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.85,
              minChildSize: 0.4,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                      ),
                      const SizedBox(height: 16),
                      const Text('Privacy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

                      // Last Seen Visibility
                      SwitchListTile(
                        title: const Text('Last Seen'),
                        subtitle: const Text('Allow others to see when you were last online'),
                        value: _user?.lastSeenVisible ?? true,
                        onChanged: (val) {
                          _updateField('lastSeenVisible', val);
                          setSheetState(() {});
                        },
                      ),
                      const Divider(),

                      // Last Seen Visibility Level
                      ListTile(
                        title: const Text('Last Seen Visibility'),
                        subtitle: Text(_user?.lastSeenVisibility ?? 'everyone'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showVisibilityPicker(context, 'lastSeenVisibility', setSheetState),
                      ),

                      // Profile Photo Visibility Level
                      ListTile(
                        title: const Text('Profile Photo'),
                        subtitle: Text(_user?.profilePhotoVisibility ?? 'everyone'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showVisibilityPicker(context, 'profilePhotoVisibility', setSheetState),
                      ),

                      const Divider(),

                      // Read Receipts
                      SwitchListTile(
                        title: const Text('Read Receipts'),
                        subtitle: const Text('If turned off, you won\'t send read receipts'),
                        value: _user?.readReceipts ?? true,
                        onChanged: (val) {
                          _updateField('readReceipts', val);
                          setSheetState(() {});
                        },
                      ),

                      const Divider(),

                      // Blocked contacts
                      ListTile(
                        title: const Text('Blocked Users'),
                        subtitle: Text('${_user?.blockedUsers.length ?? 0} contacts'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showVisibilityPicker(BuildContext context, String field, StateSetter setSheetState) {
    final options = ['everyone', 'contacts', 'nobody'];
    final current = field == 'lastSeenVisibility' ? _user?.lastSeenVisibility : _user?.profilePhotoVisibility;

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(field == 'lastSeenVisibility' ? 'Last Seen' : 'Profile Photo'),
        children: options.map((opt) => ListTile(
          title: Text(opt[0].toUpperCase() + opt.substring(1)),
          trailing: (current ?? 'everyone') == opt
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : null,
          onTap: () {
            _updateField(field, opt);
            setSheetState(() {});
            Navigator.pop(ctx);
          },
        )).toList(),
      ),
    );
  }
}
