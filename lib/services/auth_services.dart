import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  // ---------------- SIGN UP ----------------
  Future<User?> signUp(String email, String password) async {
    try {
      final cred = await _auth
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return cred.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Signup failed";
    }
  }

  // ---------------- LOGIN ----------------
  Future<User?> login(String email, String password) async {
    try {
      final cred = await _auth
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;

      if (user != null) {
        final token =
        await NotificationService.getToken();

        if (token != null) {
          await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .set(
            {"fcmToken": token},
            SetOptions(merge: true),
          );
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Login failed";
    }
  }

  // ---------------- LOGOUT ----------------
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ---------------- AUTH STATE ----------------
  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();
}