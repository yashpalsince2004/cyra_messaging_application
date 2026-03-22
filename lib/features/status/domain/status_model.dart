import 'package:cloud_firestore/cloud_firestore.dart';

class StatusModel {
  final String uid;
  final String username;
  final String phoneNumber;
  final List<String> photoUrls;
  final DateTime createdAt;
  final String profilePic;
  final String statusId;

  StatusModel({
    required this.uid,
    required this.username,
    required this.phoneNumber,
    required this.photoUrls,
    required this.createdAt,
    required this.profilePic,
    required this.statusId,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'phoneNumber': phoneNumber,
      'photoUrls': photoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'profilePic': profilePic,
      'statusId': statusId,
    };
  }

  factory StatusModel.fromMap(Map<String, dynamic> map) {
    return StatusModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      profilePic: map['profilePic'] ?? '',
      statusId: map['statusId'] ?? '',
    );
  }
}
