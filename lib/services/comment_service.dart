import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;
  String get _email => _auth.currentUser!.email ?? "Anonymous";

  // Stream comments
  Stream<QuerySnapshot> getComments(String reportId) {
    return _db
        .collection("reports")
        .doc(reportId)
        .collection("comments")
        .orderBy("createdAt", descending: false) // oldest → newest
        .snapshots();
  }


  // Add comment
  Future<void> addComment(String reportId, String text) async {
    if (text.trim().isEmpty) return;

    await _db
        .collection("reports")
        .doc(reportId)
        .collection("comments")
        .add({
      "text": text.trim(),
      "userId": _uid,
      "userEmail": _email,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
    });
  }
}