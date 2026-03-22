import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus { calling, ringing, connected, ended }

class CallModel {
  final String callId;
  final String callerId;
  final String receiverId;
  final CallStatus status;
  final DateTime createdAt;
  final String? offer;
  final String? answer;
  final List<Map<String, dynamic>>? iceCandidates;

  CallModel({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.offer,
    this.answer,
    this.iceCandidates,
  });

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'receiverId': receiverId,
      'status': status.name,
      'createdAt': createdAt,
      'offer': offer,
      'answer': answer,
      'iceCandidates': iceCandidates,
    };
  }

  factory CallModel.fromMap(Map<String, dynamic> map) {
    return CallModel(
      callId: map['callId'] ?? '',
      callerId: map['callerId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      status: CallStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'calling'),
        orElse: () => CallStatus.calling,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      offer: map['offer'],
      answer: map['answer'],
      iceCandidates: List<Map<String, dynamic>>.from(map['iceCandidates'] ?? []),
    );
  }
}