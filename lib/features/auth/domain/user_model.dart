class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phoneNo;
  final String about;
  final String? photoUrl;
  final bool lastSeenVisible;

  // Presence
  final bool isOnline;
  final DateTime? lastSeen;

  // Privacy
  final String profilePhotoVisibility; // 'everyone', 'contacts', 'nobody'
  final String lastSeenVisibility;     // 'everyone', 'contacts', 'nobody'
  final bool readReceipts;
  final List<String> blockedUsers;

  // FCM
  final String? fcmToken;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phoneNo,
    this.about = 'Hey there! I am using Cyra',
    this.photoUrl,
    this.lastSeenVisible = true,
    this.isOnline = false,
    this.lastSeen,
    this.profilePhotoVisibility = 'everyone',
    this.lastSeenVisibility = 'everyone',
    this.readReceipts = true,
    this.blockedUsers = const [],
    this.fcmToken,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['user_id'] ?? '',
      name: map['name'] ?? '',
      email: map['email_id'] ?? '',
      phoneNo: map['phone_no'] ?? '',
      about: map['about'] ?? 'Hey there! I am using Cyra',
      photoUrl: map['photoUrl'],
      lastSeenVisible: map['lastSeenVisible'] ?? true,
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as dynamic).toDate()
          : null,
      profilePhotoVisibility: map['profilePhotoVisibility'] ?? 'everyone',
      lastSeenVisibility: map['lastSeenVisibility'] ?? 'everyone',
      readReceipts: map['readReceipts'] ?? true,
      blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
      fcmToken: map['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': uid,
      'name': name,
      'email_id': email,
      'phone_no': phoneNo,
      'about': about,
      'photoUrl': photoUrl,
      'lastSeenVisible': lastSeenVisible,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'profilePhotoVisibility': profilePhotoVisibility,
      'lastSeenVisibility': lastSeenVisibility,
      'readReceipts': readReceipts,
      'blockedUsers': blockedUsers,
      'fcmToken': fcmToken,
    };
  }
}
