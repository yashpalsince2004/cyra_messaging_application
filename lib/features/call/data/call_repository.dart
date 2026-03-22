import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cyra/features/call/domain/call_model.dart';
import 'package:uuid/uuid.dart';

final callRepositoryProvider = Provider(
  (ref) => CallRepository(firestore: FirebaseFirestore.instance),
);

class CallRepository {
  final FirebaseFirestore firestore;
  final Uuid _uuid = const Uuid();

  CallRepository({required this.firestore});

  // Create a new call
  Future<String> createCall({
    required String callerId,
    required String receiverId,
  }) async {
    final callId = _uuid.v4();
    final call = CallModel(
      callId: callId,
      callerId: callerId,
      receiverId: receiverId,
      status: CallStatus.calling,
      createdAt: DateTime.now(),
    );

    await firestore.collection('calls').doc(callId).set(call.toMap());
    return callId;
  }

  // Update call status
  Future<void> updateCallStatus(String callId, CallStatus status) async {
    await firestore.collection('calls').doc(callId).update({
      'status': status.name,
    });
  }

  // Set offer
  Future<void> setOffer(String callId, String offer) async {
    await firestore.collection('calls').doc(callId).update({'offer': offer});
  }

  // Set answer
  Future<void> setAnswer(String callId, String answer) async {
    await firestore.collection('calls').doc(callId).update({'answer': answer});
  }

  // Add ICE candidate
  Future<void> addIceCandidate(
    String callId,
    Map<String, dynamic> candidate,
  ) async {
    await firestore.collection('calls').doc(callId).update({
      'iceCandidates': FieldValue.arrayUnion([candidate]),
    });
  }

  // Listen to call updates
  Stream<CallModel?> getCallStream(String callId) {
    return firestore.collection('calls').doc(callId).snapshots().map((doc) {
      if (doc.exists) {
        return CallModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  // Listen for incoming calls
  Stream<List<CallModel>> getIncomingCalls(String userId) {
    return firestore
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .where('status', whereIn: ['calling', 'ringing'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CallModel.fromMap(doc.data()))
              .toList();
        });
  }

  // End call
  Future<void> endCall(String callId) async {
    await updateCallStatus(callId, CallStatus.ended);
  }

  // Delete call document (cleanup)
  Future<void> deleteCall(String callId) async {
    await firestore.collection('calls').doc(callId).delete();
  }
}
