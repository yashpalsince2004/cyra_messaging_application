import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cyra/features/status/domain/status_model.dart';
import 'package:cyra/features/auth/domain/user_model.dart';

final statusRepositoryProvider = Provider((ref) => StatusRepository(
      firestore: FirebaseFirestore.instance,
      auth: FirebaseAuth.instance,
      storage: FirebaseStorage.instance,
    ));

class StatusRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final FirebaseStorage storage;
  final Uuid _uuid = const Uuid();

  StatusRepository({
    required this.firestore,
    required this.auth,
    required this.storage,
  });

  Future<void> uploadStatus(File statusImage) async {
    try {
      final currentUserId = auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Upload image to Firebase Storage
      final statusId = _uuid.v4();
      final storageRef = storage.ref().child('status/$currentUserId/$statusId');
      final uploadTask = await storageRef.putFile(statusImage);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      // Get current user's profile info
      final userDoc = await firestore.collection('user_db').where('user_id', isEqualTo: currentUserId).get();
      if (userDoc.docs.isEmpty) return;
      
      final userData = UserModel.fromMap(userDoc.docs.first.data());

      // Check for existing valid status (within last 24h)
      final statusQuery = await firestore
          .collection('status')
          .where('uid', isEqualTo: currentUserId)
          .get();

      bool hasExistingValidStatus = false;
      String existingStatusDocId = '';
      List<String> existingPhotoUrls = [];

      for (var doc in statusQuery.docs) {
        final status = StatusModel.fromMap(doc.data());
        final isExpired = DateTime.now().difference(status.createdAt).inHours >= 24;
        
        if (!isExpired) {
          hasExistingValidStatus = true;
          existingStatusDocId = doc.id;
          existingPhotoUrls = status.photoUrls;
          break;
        } else {
          // Cleanup old status document (optional, but good practice)
          await firestore.collection('status').doc(doc.id).delete();
        }
      }

      if (hasExistingValidStatus) {
        // Append new picture to existing status list
        existingPhotoUrls.add(imageUrl);
        await firestore.collection('status').doc(existingStatusDocId).update({
          'photoUrls': existingPhotoUrls,
        });
      } else {
        // Create brand new status model
        final newStatusId = _uuid.v4();
        final newStatus = StatusModel(
          uid: currentUserId,
          username: userData.name,
          phoneNumber: userData.phoneNo,
          photoUrls: [imageUrl],
          createdAt: DateTime.now(),
          profilePic: '', // We don't store profile pics explicitly right now, so empty
          statusId: newStatusId,
        );

        await firestore.collection('status').doc(newStatusId).set(newStatus.toMap());
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading status: $e');
      }
      rethrow;
    }
  }

  Stream<List<StatusModel>> getStatuses() {
    return firestore
        .collection('status')
        .snapshots()
        .map((snapshot) {
      List<StatusModel> statuses = [];
      for (var doc in snapshot.docs) {
        final status = StatusModel.fromMap(doc.data());
        final isExpired = DateTime.now().difference(status.createdAt).inHours >= 24;
        
        // Return only unexpired statuses
        if (!isExpired) {
          statuses.add(status);
        }
      }
      return statuses;
    });
  }
}
