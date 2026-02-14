import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // 🔥 ADD YOUR HUGGINGFACE TOKEN HERE
  final String _hfToken = "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";

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

  // ================= AI IMAGE ANALYSIS =================
  Future<Map<String, dynamic>> _analyzeImage(Uint8List bytes) async {
    final response = await http.post(
      Uri.parse(
          "https://api-inference.huggingface.co/models/google/vit-base-patch16-224"),
      headers: {
        "Authorization": "Bearer $_hfToken",
        "Content-Type": "application/octet-stream",
      },
      body: bytes,
    );

    if (response.statusCode != 200) {
      return {
        "label": "unknown",
        "confidence": 0.0,
      };
    }

    final result = jsonDecode(response.body);

    return {
      "label": result[0]["label"],
      "confidence": result[0]["score"],
    };
  }

  // ================= AI TEXT ANALYSIS =================
  Future<double> _analyzeText(String description) async {
    final response = await http.post(
      Uri.parse(
          "https://api-inference.huggingface.co/models/facebook/bart-large-mnli"),
      headers: {
        "Authorization": "Bearer $_hfToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "inputs": description,
        "parameters": {
          "candidate_labels": [
            "fire",
            "flood",
            "accident",
            "earthquake",
            "explosion"
          ]
        }
      }),
    );

    if (response.statusCode != 200) {
      return 0.0;
    }

    final result = jsonDecode(response.body);
    return result["scores"][0];
  }

  // ================= CREATE REPORT =================
  Future<void> addReport({
    required String type,
    required String description,
    required double severity,
    required List<File> images,
    required double lat,
    required double lng,
  }) async {
    if (_auth.currentUser == null) {
      throw Exception("User not authenticated");
    }

    List<String> base64Images = [];

    for (var file in images) {
      final compressed = await _compressAndConvert(file);
      base64Images.add(compressed);
    }

    // ================= AI PROCESS =================

    Map<String, dynamic> aiResult = {
      "imageLabel": "unknown",
      "imageConfidence": 0.0,
      "textConfidence": 0.0,
      "aiVerified": false,
    };

    try {
      if (images.isNotEmpty) {
        final imageBytes = await images.first.readAsBytes();

        final imageAnalysis = await _analyzeImage(imageBytes);
        final textConfidence = await _analyzeText(description);

        final bool aiVerified =
            imageAnalysis["confidence"] > 0.6 &&
                textConfidence > 0.6;

        aiResult = {
          "imageLabel": imageAnalysis["label"],
          "imageConfidence": imageAnalysis["confidence"],
          "textConfidence": textConfidence,
          "aiVerified": aiVerified,
        };
      }
    } catch (_) {
      // Fail silently for prototype
    }

    // ================= SAVE REPORT =================

    await _db.collection("reports").add({
      "type": type,
      "description": description,
      "severity": severity,
      "images": base64Images,
      "lat": lat,
      "lng": lng,
      "verified": false,
      "votes": [],
      "authorId": _uid,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
      "aiAnalysis": aiResult, // 🔥 NEW FIELD
    });
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

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw "Location services are disabled";
    }

    LocationPermission permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
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

      tx.update(ref, {
        "votes": votes,
        "verified": votes.length >= 3,
      });
    });
  }
}
