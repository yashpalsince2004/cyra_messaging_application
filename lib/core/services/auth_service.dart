import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      // Save user to Firestore
      if (credential.user != null) {
        await _firestore.collection('user_db').doc(credential.user!.uid).set({
          'user_id': credential.user!.uid,
          'email_id': credential.user!.email,
          'phone_no': credential.user!.phoneNumber ?? '',
          'name': email.split('@')[0], // default name from email
          'createdAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'lastActive': FieldValue.serverTimestamp(),
        });
      }
      
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final authCredential = await _auth.signInWithCredential(credential);
      
      // Save user to Firestore if they don't exist
      if (authCredential.user != null) {
        final userDoc = await _firestore.collection('user_db').doc(authCredential.user!.uid).get();
        if (!userDoc.exists) {
          await _firestore.collection('user_db').doc(authCredential.user!.uid).set({
            'user_id': authCredential.user!.uid,
            'email_id': authCredential.user!.email,
            'phone_no': authCredential.user!.phoneNumber ?? '',
            'name': authCredential.user!.displayName ?? authCredential.user!.email?.split('@')[0] ?? 'User',
            'photoUrl': authCredential.user!.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
            'isOnline': true,
            'lastActive': FieldValue.serverTimestamp(),
          });
        } else {
           // Update online status
           await _firestore.collection('user_db').doc(authCredential.user!.uid).update({
             'isOnline': true,
             'lastActive': FieldValue.serverTimestamp(),
           });
        }
      }
      
      return authCredential;
    } catch (e) {
      throw 'Failed to sign in with Google: ${e.toString()}';
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      throw 'Failed to sign out: ${e.toString()}';
    }
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
}
