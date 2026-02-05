import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/loading_state.dart';
import '../widgets/empty_state.dart';
import 'map_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // 🔴 Severity color helper
  Color _severityColor(int s) {
    if (s >= 4) return Colors.red;
    if (s >= 2) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("reports")
          .snapshots(),

      builder: (context, snapshot) {

        // 🔄 Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingState(
            message: "Loading verified reports...",
          );
        }

        // ❌ Error
        if (snapshot.hasError) {
          return Center(
            child: Text(snapshot.error.toString()),
          );
        }

        // 📭 No data
        if (!snapshot.hasData) {
          return const EmptyState(
            icon: Icons.inbox,
            title: "No verified reports",
            subtitle: "Once reports are verified, they will appear here.",
          );
        }

        // 🔥 Filter only verified reports
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data.containsKey("verified") &&
              data["verified"] == true;
        }).toList();

        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.verified_outlined,
            title: "No verified reports yet",
            subtitle: "Verified incidents will appear here.",
          );
        }

        return ListView(
          children: [

            // ================= HEADER =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Verified Incidents",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Confirmed by nearby users",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ================= CARDS =================
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ================= HEADER =================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Row(
                        children: [

                          // 🔴 ICON BADGE
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 26,
                            ),
                          ),

                          const SizedBox(width: 12),

                          // TYPE TEXT
                          Expanded(
                            child: Text(
                              data["type"] ?? "Unknown",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          // SEVERITY CHIP
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _severityColor(
                                (data["severity"] ?? 1).toInt(),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "S${(data["severity"] ?? 1).toInt()}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ================= IMAGE =================
                    if (data["images"] != null && data["images"].isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                        ),
                        child: Image.file(
                          File(data["images"][0]),
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),

                    // ================= DESCRIPTION =================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: Text(
                        data["description"] ?? "",
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.5),
                      ),
                    ),

                    const Divider(height: 1),

                    // ================= ACTIONS =================
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          // 📍 MAP
                          TextButton.icon(
                            icon: const Icon(Icons.map_outlined),
                            label: const Text("View location"),
                            onPressed: () {
                              if (data["lat"] == null || data["lng"] == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Location not available"),
                                  ),
                                );
                                return;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapScreen(
                                    lat: data["lat"],
                                    lng: data["lng"],
                                  ),
                                ),
                              );
                            },
                          ),

                          // ✅ VERIFIED ICON (HOME)
                          const Icon(
                            Icons.verified,
                            color: Colors.green,
                          ),
                        ],
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
