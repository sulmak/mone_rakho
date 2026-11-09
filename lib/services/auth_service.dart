import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase Authentication service supporting online sync, user profile info saving, & offline mode.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  bool isOfflineMode = false;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  Stream<User?> get authStateChanges => FirebaseAuth.instance.authStateChanges();

  Future<UserCredential?> signIn(String email, String password) async {
    isOfflineMode = false;
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    if (credential.user != null) {
      await saveUserInfo(credential.user!);
    }
    return credential;
  }

  Future<UserCredential?> signUp(String email, String password) async {
    isOfflineMode = false;
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    if (credential.user != null) {
      await saveUserInfo(credential.user!);
    }
    return credential;
  }

  Future<void> saveUserInfo(User user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> signOut() async {
    isOfflineMode = false;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
