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

  // 🔴 Severity color helper
  Color _severityColor(int s) {
    if (s >= 4) return Colors.red;
    if (s >= 2) return Colors.orange;
    return Colors.green;
  }

  // 🕒 Date & Time formatter
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

  // 📍 200m distance check
  Future<bool> _isUserWithin200m(
      double reportLat,
      double reportLng,
      ) async {
    bool serviceEnabled =
    await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    final position =
    await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      reportLat,
      reportLng,
    );

    return distance <= 200; // 🔥 200 meters
  }

  @override
  Widget build(BuildContext context) {
    final service = ReportService();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("reports")
          .orderBy("createdAt", descending: true)
          .snapshots(),

      builder: (context, snapshot) {
        // 🔄 LOADING
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const LoadingState(
            message: "Loading reports to verify...",
          );
        }

        // ❌ ERROR
        if (snapshot.hasError) {
          return Center(
            child: Text(snapshot.error.toString()),
          );
        }

        if (!snapshot.hasData) {
          return const EmptyState(
            icon: Icons.error_outline,
            title: "No data",
            subtitle: "Unable to load reports.",
          );
        }

        // 🔥 Only UNVERIFIED reports
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
          children: [
            // ===== HEADER =====
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.fromLTRB(16, 20, 16, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFD32F2F),
                    Color(0xFFB71C1C),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: const Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    "Verify Reports",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Confirm incidents near you",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ===== CARDS =====
            ...docs.map((doc) {
              final data =
              doc.data() as Map<String, dynamic>;
              final votes =
                  (data["votes"] as List?) ?? [];

              return Card(
                elevation: 2,
                shadowColor: Colors.black26,
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Padding(
                      padding:
                      const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.orange
                                  .withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.help_outline,
                              color: Colors.orange,
                              size: 26,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data["type"] ??
                                      "Unknown",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                    fontWeight:
                                    FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDateTime(
                                      data["createdAt"]),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _severityColor(
                                (data["severity"] ?? 1)
                                    .toInt(),
                              ),
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            child: Text(
                              "S${(data["severity"] ?? 1).toInt()}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // IMAGE
                    if (data["images"] != null &&
                        data["images"].isNotEmpty)
                      ClipRRect(
                        borderRadius:
                        const BorderRadius.only(
                          topLeft:
                          Radius.circular(14),
                          topRight:
                          Radius.circular(14),
                        ),
                        child: Image.file(
                          File(data["images"][0]),
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) =>
                          const SizedBox(),
                        ),
                      ),

                    // DESCRIPTION
                    Padding(
                      padding:
                      const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: Text(
                        data["description"] ?? "",
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.5),
                      ),
                    ),

                    const Divider(height: 1),

                    // ACTIONS
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            icon: const Icon(
                                Icons.map_outlined),
                            label:
                            const Text("View location"),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MapScreen(
                                        lat: data["lat"],
                                        lng: data["lng"],
                                      ),
                                ),
                              );
                            },
                          ),

                          ElevatedButton.icon(
                            icon:
                            const Icon(Icons.check),
                            label:
                            const Text("Verify"),
                            onPressed: () async {
                              final isNearby =
                              await _isUserWithin200m(
                                data["lat"],
                                data["lng"],
                              );

                              if (!isNearby) {
                                ScaffoldMessenger.of(
                                    context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "You must be within 200 meters to verify",
                                    ),
                                  ),
                                );
                                return;
                              }

                              try {
                                await service.vote(
                                    doc.id);

                                ScaffoldMessenger.of(
                                    context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Verification added",
                                    ),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(
                                    context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        e.toString()),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // FOOTER
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 12,
                        bottom: 8,
                      ),
                      child: Text(
                        "Votes: ${votes.length}/3",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}
