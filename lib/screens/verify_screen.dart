import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../services/report_service.dart';
import '../widgets/loading_state.dart';
import '../widgets/empty_state.dart';
import 'map_screen.dart';

class VerifyScreen extends StatelessWidget {
  const VerifyScreen({super.key});

  // ================= HELPERS =================

  Color _severityColor(int s) {
    if (s >= 4) return Colors.red;
    if (s >= 2) return Colors.orange;
    return Colors.green;
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return "";

    DateTime date;

    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is int) {
      date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return "";
    }

    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}  "
        "${date.hour.toString().padLeft(2, '0')}:"
        "${date.minute.toString().padLeft(2, '0')}";
  }

  // ================= SAFE IMAGE =================

  Widget _buildImage(dynamic imageData) {
    if (imageData == null) return const SizedBox();

    try {
      if (imageData is String &&
          !imageData.startsWith("/data/") &&
          !imageData.startsWith("file:")) {
        return Image.memory(
          base64Decode(imageData),
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      }

      if (imageData is String) {
        final file = File(imageData);
        if (file.existsSync()) {
          return Image.file(
            file,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
          );
        }
      }
    } catch (_) {}

    return const SizedBox();
  }

  // ================= AI PANEL =================

  Widget _buildAIPanel(Map<String, dynamic>? ai) {
    if (ai == null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text("AI analysis in progress..."),
          ],
        ),
      );
    }

    final double confidence =
    (ai["confidence"] ?? 0).toDouble();

    final int matchScore =
    (ai["match_score"] ?? 0).toInt();

    final String summary =
        ai["ai_summary"] ?? "No summary";

    final String alertType =
        ai["alert_type"] ?? "Unknown";

    Color confidenceColor;
    if (confidence > 0.85) {
      confidenceColor = Colors.green;
    } else if (confidence > 0.6) {
      confidenceColor = Colors.orange;
    } else {
      confidenceColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: confidenceColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: confidenceColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Match Score Badge (primary signal)
          Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                color: confidenceColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                "Match Score: $matchScore / 10",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: confidenceColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Alert Type
          Text(
            "Detected Type: $alertType",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 6),

          // AI Summary
          Text(
            summary,
            style: const TextStyle(fontSize: 13),
          ),

          const SizedBox(height: 8),

          // AI Confidence (secondary signal)
          Text(
            "AI Confidence: ${(confidence * 100).toStringAsFixed(1)}%",
            style: const TextStyle(fontSize: 12),
          ),

          // Warning if mismatch
          if (matchScore < 5)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "⚠ The image does not clearly match the description.",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ================= DISTANCE CHECK =================

  Future<bool> _isUserWithin200m(
      double reportLat,
      double reportLng) async {

    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }

    LocationPermission permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }

    if (permission ==
        LocationPermission.deniedForever) {
      return false;
    }

    final position =
    await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final distance =
    Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      reportLat,
      reportLng,
    );

    return distance <= 200;
  }

  // ================= SAFE AUTO DELETE =================

  void _safeDeleteIfExpired(
      QueryDocumentSnapshot doc,
      Map<String, dynamic> data) {

    if (data["createdAt"] == null) return;

    final Timestamp ts = data["createdAt"];
    final reportTime = ts.toDate();

    final difference =
    DateTime.now().difference(reportTime);

    final expired24 =
        difference.inHours >= 24;

    if (expired24 &&
        data["verified"] == false) {
      Future.microtask(() {
        FirebaseFirestore.instance
            .collection("reports")
            .doc(doc.id)
            .delete()
            .catchError((_) {
          // Some roles may not have delete permissions based on
          // Firestore rules. Ignore silently to prevent UI crashes.
        });
      });
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("reports")
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const LoadingState(
            message: "Loading reports to verify...",
          );
        }

        if (!snapshot.hasData) {
          return const EmptyState(
            icon: Icons.error_outline,
            title: "No data",
            subtitle:
            "Unable to load reports.",
          );
        }

        final docs =
        snapshot.data!.docs.where((doc) {
          final data =
          doc.data() as Map<String, dynamic>;
          return data["verified"] == false;
        }).toList();

        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.verified_outlined,
            title: "No reports to verify",
            subtitle:
            "All nearby incidents are verified.",
          );
        }

        return ListView(
          children: docs.map((doc) {

            final data =
            doc.data() as Map<String, dynamic>;

            final votes =
                (data["votes"] as List?) ?? [];

            final requiredVotes =
            (data["requiredVotes"] ?? 3)
                .toInt();

            if (data["createdAt"] == null) {
              return const SizedBox();
            }

            final Timestamp ts =
            data["createdAt"];

            final reportTime = ts.toDate();

            final difference =
            DateTime.now()
                .difference(reportTime);

            final expired15 =
                difference.inMinutes >= 15;

            final remainingMinutes =
                15 - difference.inMinutes;

            _safeDeleteIfExpired(doc, data);

            return Card(
              margin:
              const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [

                  // HEADER
                  Padding(
                    padding:
                    const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.help_outline,
                          color:
                          Colors.orange,
                        ),
                        const SizedBox(
                            width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Text(
                                data["type"] ??
                                    "Unknown",
                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                ),
                              ),
                              Text(
                                _formatDateTime(
                                    data[
                                    "createdAt"]),
                                style:
                                const TextStyle(
                                  fontSize: 12,
                                  color: Colors
                                      .grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration:
                          BoxDecoration(
                            color:
                            _severityColor(
                              (data["severity"] ??
                                  1)
                                  .toInt(),
                            ),
                            borderRadius:
                            BorderRadius
                                .circular(
                                20),
                          ),
                          child: Text(
                            "S${data["severity"]}",
                            style:
                            const TextStyle(
                              color:
                              Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // IMAGE
                  if (data["images"] != null &&
                      data["images"]
                      is List &&
                      data["images"]
                          .isNotEmpty)
                    Padding(
                      padding:
                      const EdgeInsets
                          .symmetric(
                          horizontal:
                          12),
                      child: ClipRRect(
                        borderRadius:
                        BorderRadius
                            .circular(
                            14),
                        child:
                        _buildImage(
                          data["images"]
                          [0],
                        ),
                      ),
                    ),

                  // AI PANEL
                  if (data["aiAnalysis"] == null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: const [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text("AI analysis in progress..."),
                        ],
                      ),
                    ),

                  // DESCRIPTION
                  Padding(
                    padding:
                    const EdgeInsets
                        .all(12),
                    child: Text(
                        data["description"] ??
                            ""),
                  ),
                  _buildAIPanel(data["aiAnalysis"] as Map<String, dynamic>?),

                  const Divider(
                      height: 1),

                  // ACTIONS
                  Padding(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                      children: [

                        TextButton.icon(
                          icon: const Icon(
                              Icons
                                  .map_outlined),
                          label: const Text(
                              "Location"),
                          onPressed: () {
                            if (data["lat"] ==
                                null ||
                                data["lng"] ==
                                    null)
                              return;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MapScreen(
                                      lat: data[
                                      "lat"],
                                      lng: data[
                                      "lng"],
                                      reportData: data,
                                    ),
                              ),
                            );
                          },
                        ),

                        ElevatedButton.icon(
                          icon:
                          const Icon(
                              Icons
                                  .check),
                          label: Text(
                              expired15
                                  ? "Expired"
                                  : "Verify"),
                          onPressed:
                          expired15
                              ? null
                              : () async {

                            final
                            isNearby =
                            await _isUserWithin200m(
                                data[
                                "lat"],
                                data[
                                "lng"]);

                            if (!isNearby) {
                              ScaffoldMessenger.of(
                                  context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "You must be within 200 meters"),
                                ),
                              );
                              return;
                            }

                            try {
                              await service.vote(doc.id);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding:
                    const EdgeInsets
                        .only(
                      left: 12,
                      right: 12,
                      bottom: 4,
                    ),
                    child: Text(
                      expired15
                          ? "Verification closed (15 min limit)"
                          : "Verification open • $remainingMinutes min left",
                      style:
                      TextStyle(
                        fontSize: 12,
                        color: expired15
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ),

                  Padding(
                    padding:
                    const EdgeInsets
                        .only(
                      left: 12,
                      right: 12,
                      bottom: 8,
                    ),
                    child: Text(
                      "Votes: ${votes.length}/$requiredVotes",
                      style:
                      const TextStyle(
                        fontSize: 12,
                        color:
                        Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
