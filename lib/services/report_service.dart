import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ---------------- CREATE REPORT ----------------
  Future<void> addReport({
    required String type,
    required String description,
    required double severity,
    required List<String> images,
    required double lat,
    required double lng,
  }) async {
    await _db.collection("reports").add({
      "type": type,
      "description": description,
      "severity": severity,
      "images": images,
      "lat": lat,
      "lng": lng,
      "authorId": _uid,
      "votes": [],
      "verified": false,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ---------------- STREAMS ----------------
  Stream<QuerySnapshot> getVerifiedReports() {
    return _db.collection("reports").snapshots();
  }

  Stream<QuerySnapshot> getUnverifiedReports() {
    return _db.collection("reports").snapshots();
  }

  // ---------------- DISTANCE BASED VERIFY ----------------
  Future<void> vote(String reportId) async {
    final ref = _db.collection("reports").doc(reportId);

    // 1️⃣ Get user location
    final Position userPosition =
    await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data()!;

      final String author = data["authorId"];
      final List votes = List.from(data["votes"]);

      final double reportLat = data["lat"];
      final double reportLng = data["lng"];

      //  Author cannot verify
      if (author == _uid) {
        throw "You cannot verify your own report";
      }

      // Already voted
      if (votes.contains(_uid)) {
        throw "You already verified this report";
      }

      // 2️⃣ Calculate distance
      final double distance = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        reportLat,
        reportLng,
      );

      // Too far (200 meters)
      if (distance > 200) {
        throw "You must be within 150 meters to verify this report";
      }

      // 3️⃣ Add vote
      votes.add(_uid);

      final bool verified = votes.length >= 3;

      tx.update(ref, {
        "votes": votes,
        "verified": verified,
      });
    });
  }
}
