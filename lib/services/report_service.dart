import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'ai_verification_service.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ================= IMAGE COMPRESSION =================
  Future<String> _compressAndConvert(File file) async {
    final compressedBytes =
    await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 800,
      minHeight: 800,
      quality: 60,
    );

    if (compressedBytes == null) {
      throw Exception("Image compression failed");
    }

    if (compressedBytes.length > 800000) {
      throw Exception("Image still too large after compression.");
    }

    return base64Encode(compressedBytes);
  }

  // ================= CREATE REPORT =================
  Future<void> addReport({
    required String type,
    required String description,
    required double severity,
    required List<File> images,
    required double lat,
    required double lng,
    required Map<String, dynamic> aiAnalysis, // not used directly
  }) async {
    if (_auth.currentUser == null) {
      throw Exception("User not authenticated");
    }

    // Compress images
    List<String> base64Images = [];

    for (var file in images) {
      final compressed = await _compressAndConvert(file);
      base64Images.add(compressed);
    }

    // Save report immediately
    final docRef = await _db.collection("reports").add({
      "type": type,
      "description": description,
      "severity": severity,
      "lat": lat,
      "lng": lng,
      "images": base64Images,
      "verified": false,
      "verifiedByRole": null,
      "requiredVotes": 3,
      "votes": [],
      "authorId": _uid,
      "createdAt": FieldValue.serverTimestamp(),
      "aiAnalysis": null,
    });

    // Run AI in background
    _runAiInBackground(docRef, images, description, type);
  }

  // ================= BACKGROUND AI =================
  Future<void> _runAiInBackground(
      DocumentReference docRef,
      List<File> images,
      String description,
      String type,
      ) async {
    try {
      print("🔥 AI BACKGROUND STARTED");

      if (images.isEmpty) return;

      Uint8List imageBytes = await images.first.readAsBytes();

      // ===== OPTION A: REAL GEMINI =====
      final aiResult = await AiVerificationService().verifyReport(
        imageBytes: imageBytes,
        description: description,
        selectedType: type,
      );

      // ===== OPTION B: TEST MODE (uncomment to test Firestore update) =====
      /*
      await Future.delayed(const Duration(seconds: 2));
      final aiResult = {
        "is_disaster": true,
        "confidence": 0.95,
        "ai_summary": "Smoke and flames detected.",
        "match_score": 9,
        "alert_type": "Fire"
      };
      */

      int requiredVotes = 3;

      final double confidence =
      (aiResult["confidence"] ?? 0).toDouble();

      final int matchScore =
      (aiResult["match_score"] ?? 0).toInt();

      if (confidence > 0.9 && matchScore > 8) {
        requiredVotes = 2;
      }

      await docRef.update({
        "aiAnalysis": aiResult,
        "requiredVotes": requiredVotes,
      });

      print("✅ AI UPDATE SUCCESS");

    } catch (e) {
      print("🔥 AI BACKGROUND ERROR: $e");
    }
  }

  // ================= STREAMS =================
  Stream<QuerySnapshot> getVerifiedReports() {
    return _db
        .collection("reports")
        .where("verified", isEqualTo: true)
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getUnverifiedReports() {
    return _db
        .collection("reports")
        .where("verified", isEqualTo: false)
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  // ================= DISTANCE VERIFY =================
  Future<void> vote(String reportId) async {
    if (_auth.currentUser == null) {
      throw "User not logged in";
    }

    final ref = _db.collection("reports").doc(reportId);
    final userDoc = await _db.collection("users").doc(_uid).get();
    final String userRole = (userDoc.data()?['role'] ?? 'community')
        .toString()
        .toLowerCase();
    final bool isAuthorityReviewer =
        userRole == 'ngo' || userRole == 'govt_authority';

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw "Location services are disabled";
    }

    LocationPermission permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw "Location permission permanently denied";
    }

    final userPosition =
    await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);

      if (!snap.exists) {
        throw "Report not found";
      }

      final data = snap.data()!;
      final String authorId = data["authorId"] ?? "";
      final List votes = List.from(data["votes"] ?? []);
      final int requiredVotes =
      (data["requiredVotes"] ?? 3) as int;

      final double reportLat =
      (data["lat"] as num).toDouble();
      final double reportLng =
      (data["lng"] as num).toDouble();

      if (authorId == _uid) {
        throw "You cannot verify your own report";
      }

      if (votes.contains(_uid)) {
        throw "You already verified this report";
      }

      final distance =
      Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        reportLat,
        reportLng,
      );

      if (distance > 200) {
        throw "You must be within 200 meters to verify";
      }

      votes.add(_uid);

      final bool verifiedByVotes = votes.length >= requiredVotes;
      final bool verified = isAuthorityReviewer || verifiedByVotes;

      tx.update(ref, {
        "votes": votes,
        "verified": verified,
        "verifiedByRole": isAuthorityReviewer ? userRole : data["verifiedByRole"],
      });
    });
  }
}
