import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'natural_map_screen.dart';
import '../widgets/loading_state.dart';
import '../widgets/empty_state.dart';
import 'incident_details_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ================= HELPERS =================

  bool _isManMade(String type) {
    final t = type.toLowerCase();
    return t.contains("accident") ||
        t.contains("fire") ||
        t.contains("road") ||
        t.contains("riot") ||
        t.contains("explosion") ||
        t.contains("flood");
  }

  Color _severityColor(int s) {
    if (s >= 4) return Colors.red;
    if (s >= 2) return Colors.orange;
    return Colors.green;
  }

  String _formatDateTime(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return "${d.day.toString().padLeft(2, '0')}-"
        "${d.month.toString().padLeft(2, '0')}-"
        "${d.year} • "
        "${d.hour.toString().padLeft(2, '0')}:"
        "${d.minute.toString().padLeft(2, '0')}";
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


  // ================= AI BADGE =================

  Widget _buildAIBadge(Map<String, dynamic>? ai) {
    if (ai == null) return const SizedBox();

    final double confidence =
    (ai["imageConfidence"] ?? 0.0).toDouble();

    final bool verified =
        ai["aiVerified"] ?? false;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: verified
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified : Icons.smart_toy,
            size: 14,
            color: verified ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            "${(confidence * 100).toStringAsFixed(0)}% AI confidence",
            style: TextStyle(
              fontSize: 11,
              color: verified
                  ? Colors.green
                  : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  // ================= INDIA EARTHQUAKES =================

  Future<List<Map<String, dynamic>>> _fetchIndiaEarthquakes() async {
    final url = Uri.parse(
      "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_week.geojson",
    );

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception("Failed to load earthquakes");
    }

    final data = json.decode(res.body);
    final List features = data["features"];

    return features.where((e) {
      final coords = e["geometry"]["coordinates"];
      final lon = coords[0];
      final lat = coords[1];
      return lat >= 6 && lat <= 37 && lon >= 68 && lon <= 97;
    }).map((e) => e as Map<String, dynamic>).toList();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Disasters",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.warning_amber_rounded), text: "Reported"),
              Tab(icon: Icon(Icons.public), text: "Natural (India)"),
            ],
          ),
        ),
        body: TabBarView(
          children: [

            // ================= REPORTED =================
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("reports")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const LoadingState(
                    message: "Loading verified incidents...",
                  );
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.inbox,
                    title: "No verified incidents",
                    subtitle: "Nothing reported yet",
                  );
                }

                final docs =
                snapshot.data!.docs.where((doc) {
                  final data =
                  doc.data() as Map<String, dynamic>;
                  return data["verified"] == true &&
                      _isManMade(data["type"] ?? "");
                }).toList();

                if (docs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.verified_outlined,
                    title: "No verified incidents",
                    subtitle: "Nothing reported yet",
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data =
                    doc.data() as Map<String, dynamic>;

                    final ai =
                    data["aiAnalysis"] as Map<String, dynamic>?;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
                                  Icons
                                      .warning_amber_rounded,
                                  color: Colors.red,
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
                                      _buildAIBadge(ai),
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
                              data["images"] is List &&
                              data["images"]
                                  .isNotEmpty)
                            ClipRRect(
                              borderRadius:
                              BorderRadius
                                  .circular(14),
                              child: _buildImage(
                                  data["images"][0]),
                            ),

                          Padding(
                            padding:
                            const EdgeInsets.all(12),
                            child: Text(
                                data["description"] ??
                                    ""),
                          ),

                          const Divider(height: 1),

                          Padding(
                            padding:
                            const EdgeInsets.symmetric(
                                horizontal: 8),
                            child: Row(
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
                                TextButton.icon(
                                  icon: const Icon(
                                      Icons
                                          .forum_outlined),
                                  label:
                                  const Text(
                                      "Details"),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            IncidentDetailsScreen(
                                              reportId:
                                              doc.id,
                                              reportData:
                                              data,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            // ================= NATURAL TAB =================
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchIndiaEarthquakes(),
              builder: (context, snapshot) {

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const EmptyState(
                    icon: Icons.public,
                    title: "No recent disasters",
                    subtitle:
                    "No natural disasters in India this week",
                  );
                }

                final data = snapshot.data!;

                return Column(
                  children: [

                    // 🔥 VIEW ON MAP BUTTON (NaturalMapScreen now used)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.map),
                          label: const Text("View on Map"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    NaturalMapScreen(
                                      earthquakes: data,
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // 📋 LIST
                    Expanded(
                      child: ListView.builder(
                        itemCount: data.length,
                        itemBuilder: (context, i) {

                          final p = data[i]["properties"];
                          final mag =
                              (p["mag"] as num?)?.toDouble() ?? 0.0;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6),
                            child: ListTile(
                              leading: Icon(
                                Icons.public,
                                color: mag >= 5
                                    ? Colors.red
                                    : mag >= 4
                                    ? Colors.orange
                                    : Colors.yellow,
                              ),
                              title: Text(
                                  p["place"] ?? "Unknown location"),
                              subtitle: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text("Magnitude: $mag"),
                                  Text(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      p["time"] ?? 0,
                                    ).toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),

          ],
        ),
      ),
    );
  }
}
