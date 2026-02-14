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
    final date =
    DateTime.fromMillisecondsSinceEpoch(timestamp);
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
      // Base64 image
      if (imageData is String &&
          !imageData.startsWith("/data/") &&
          !imageData.startsWith("file:")) {
        return Image.memory(
          base64Decode(imageData),
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      }

      // Old file path image
      if (imageData is String) {
        final file = File(imageData);

        if (file.existsSync()) {
          return Image.file(
            file,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
          );
        } else {
          return const SizedBox(); // 🔥 Prevent crash
        }
      }
    } catch (_) {
      return const SizedBox();
    }

    return const SizedBox();
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
    final createdAt = data["createdAt"] ?? 0;
    final reportTime =
    DateTime.fromMillisecondsSinceEpoch(createdAt);

    final difference =
    DateTime.now().difference(reportTime);

    final expired24 =
        difference.inHours >= 24;

    if (expired24 && data["verified"] == false) {
      // 🔥 Delete safely outside build cycle
      Future.microtask(() {
        FirebaseFirestore.instance
            .collection("reports")
            .doc(doc.id)
            .delete();
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

            final createdAt =
                data["createdAt"] ?? 0;
            final reportTime =
            DateTime.fromMillisecondsSinceEpoch(
                createdAt);

            final difference =
            DateTime.now()
                .difference(reportTime);

            // 🔥 15 MIN WINDOW
            final expired15 =
                difference.inMinutes >= 15;
            final remainingMinutes =
                15 - difference.inMinutes;

            // 🔥 SAFE 24H AUTO DELETE
            _safeDeleteIfExpired(doc, data);

            return Card(
              margin:
              const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10),
              shape: RoundedRectangleBorder(
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
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
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
                                  color:
                                  Colors.grey,
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
                            color: _severityColor(
                                (data["severity"] ??
                                    1)
                                    .toInt()),
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
                          .isNotEmpty)
                    ClipRRect(
                      borderRadius:
                      const BorderRadius
                          .only(
                        topLeft:
                        Radius.circular(
                            14),
                        topRight:
                        Radius.circular(
                            14),
                      ),
                      child: _buildImage(
                          data["images"][0]),
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

                  const Divider(height: 1),

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
                          label:
                          const Text(
                              "Location"),
                          onPressed: () {
                            if (data["lat"] ==
                                null ||
                                data["lng"] ==
                                    null) return;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MapScreen(
                                      lat: data[
                                      "lat"],
                                      lng: data[
                                      "lng"],
                                    ),
                              ),
                            );
                          },
                        ),

                        ElevatedButton.icon(
                          icon: const Icon(
                              Icons.check),
                          label: Text(
                              expired15
                                  ? "Expired"
                                  : "Verify"),
                          style:
                          ElevatedButton
                              .styleFrom(
                            backgroundColor:
                            expired15
                                ? Colors
                                .grey
                                : null,
                          ),
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
                              "lng"],
                            );

                            if (!isNearby) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content:
                                  Text("You must be within 200 meters"),
                                ),
                              );
                              return;
                            }

                            await service.vote(
                                doc.id);
                          },
                        ),
                      ],
                    ),
                  ),

                  // STATUS TEXT
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
                      style: TextStyle(
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
                      "Votes: ${votes.length}/3",
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
