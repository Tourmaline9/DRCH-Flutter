import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_service.dart';

class AuthService {

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current user
  User? get currentUser => _auth.currentUser;

  // ---------------- SIGNUP ----------------
  Future<User?> signUp(String email, String password) async {

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = cred.user;

    // Save FCM token after signup
    if (user != null) {
      await _saveToken(user.uid);
    }

    return user;
  }

  // ---------------- LOGIN ----------------
  Future<User?> login(String email, String password) async {

    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = cred.user;

    // Save FCM token after login
    if (user != null) {
      await _saveToken(user.uid);
    }

    return user;
  }

  // ---------------- SAVE TOKEN ----------------
  Future<void> _saveToken(String uid) async {

    final token = await NotificationService.getToken();

    if (token != null) {

      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .set({
        "fcmToken": token,
      }, SetOptions(merge: true));
    }
  }

  // ---------------- LOGOUT ----------------
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ---------------- AUTH STREAM ----------------
  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();
}
