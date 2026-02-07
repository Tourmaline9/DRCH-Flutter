import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class IncidentDetailsScreen extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic> reportData;

  const IncidentDetailsScreen({
    super.key,
    required this.reportId,
    required this.reportData,
  });

  @override
  State<IncidentDetailsScreen> createState() =>
      _IncidentDetailsScreenState();
}

class _IncidentDetailsScreenState
    extends State<IncidentDetailsScreen> {
  bool _checking = false;
  bool _isPresent = false;
  int _presenceCount = 0;

  final _requirementController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPresence();
  }

  // ================= PRESENCE =================
  void _loadPresence() {
    final presence =
        (widget.reportData["presence"] as Map?) ?? {};
    final uid = FirebaseAuth.instance.currentUser!.uid;

    setState(() {
      _presenceCount = presence.length;
      _isPresent = presence.containsKey(uid);
    });
  }

  // ================= DISTANCE CHECK =================
  Future<bool> _isWithin200m(double lat, double lng) async {
    final pos = await Geolocator.getCurrentPosition();
    final distance = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      lat,
      lng,
    );
    return distance <= 200;
  }

  // ================= I'M HERE =================
  Future<void> _markPresence() async {
    setState(() => _checking = true);

    final lat = widget.reportData["lat"];
    final lng = widget.reportData["lng"];

    if (lat == null || lng == null) {
      _show("Location not available");
      setState(() => _checking = false);
      return;
    }

    if (!await _isWithin200m(lat, lng)) {
      _show("You must be within 200 meters");
      setState(() => _checking = false);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection("reports")
        .doc(widget.reportId)
        .set({
      "presence": {
        uid: {
          "timestamp": DateTime.now().millisecondsSinceEpoch,
        }
      }
    }, SetOptions(merge: true));

    setState(() {
      _isPresent = true;
      _presenceCount++;
      _checking = false;
    });

    _show("You are marked as present");
  }

  // ================= ADD REQUIREMENT =================
  Future<void> _addRequirement() async {
    if (_requirementController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection("reports")
        .doc(widget.reportId)
        .collection("requirements")
        .add({
      "title": _requirementController.text.trim(),
      "createdBy": FirebaseAuth.instance.currentUser!.uid,
      "fulfilled": false,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
    });

    _requirementController.clear();
  }

  // ================= CONTRIBUTION DIALOG =================
  Future<void> _showContributionDialog(String requirementId) async {
    final controller = TextEditingController();
    final user = FirebaseAuth.instance.currentUser!;

    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    final userName =
        userDoc.data()?["name"] ?? user.email ?? "Unknown user";

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Contribute"),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: "Describe what you can contribute",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;

              await FirebaseFirestore.instance
                  .collection("reports")
                  .doc(widget.reportId)
                  .collection("requirements")
                  .doc(requirementId)
                  .collection("contributions")
                  .add({
                "uid": user.uid,
                "name": userName,
                "message": controller.text.trim(),
                "createdAt":
                DateTime.now().millisecondsSinceEpoch,
                "upvotes": [],
              });

              Navigator.pop(context);
              _show("Contribution added");
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Incident Details")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.reportData["type"] ?? "Incident",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(widget.reportData["description"] ?? ""),
          const SizedBox(height: 24),

          // ===== PRESENCE =====
          Card(
            child: ListTile(
              leading: const Icon(Icons.people),
              title: Text("$_presenceCount people present"),
              trailing: ElevatedButton(
                onPressed:
                _isPresent || _checking ? null : _markPresence,
                child:
                Text(_isPresent ? "You’re here" : "I’m here"),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ===== REQUIREMENTS =====
          const Text(
            "Requirements",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          if (_isPresent) ...[
            TextField(
              controller: _requirementController,
              decoration: const InputDecoration(
                hintText: "Add requirement (e.g. Water)",
              ),
            ),
            ElevatedButton(
              onPressed: _addRequirement,
              child: const Text("Add Requirement"),
            ),
          ],

          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("reports")
                .doc(widget.reportId)
                .collection("requirements")
                .orderBy("createdAt", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData ||
                  snapshot.data!.docs.isEmpty) {
                return const Text(
                  "No requirements added yet",
                  style: TextStyle(color: Colors.grey),
                );
              }

              return Column(
                children: snapshot.data!.docs.map((req) {
                  final r = req.data() as Map<String, dynamic>;
                  final fulfilled = r["fulfilled"] ?? false;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ===== TITLE + ACTIONS =====
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                r["title"],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (!fulfilled)
                                ElevatedButton(
                                  onPressed: () =>
                                      _showContributionDialog(req.id),
                                  child: const Text("Contribute"),
                                )
                              else
                                const Chip(
                                  label: Text("Fulfilled"),
                                  backgroundColor: Colors.green,
                                  labelStyle:
                                  TextStyle(color: Colors.white),
                                ),
                            ],
                          ),

                          // ===== MARK FULFILLED =====
                          if (_isPresent && !fulfilled)
                            TextButton.icon(

                              label: const Text("Mark Fulfilled"),
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection("reports")
                                    .doc(widget.reportId)
                                    .collection("requirements")
                                    .doc(req.id)
                                    .update({"fulfilled": true});

                                _show("Requirement marked fulfilled");
                              },
                            ),

                          const SizedBox(height: 8),

                          // ===== CONTRIBUTIONS =====
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection("reports")
                                .doc(widget.reportId)
                                .collection("requirements")
                                .doc(req.id)
                                .collection("contributions")
                                .orderBy("createdAt", descending: true)
                                .snapshots(),
                            builder: (context, snap) {
                              if (!snap.hasData ||
                                  snap.data!.docs.isEmpty) {
                                return const Text(
                                  "No contributions yet",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                );
                              }

                              return Column(
                                children: snap.data!.docs.map((c) {
                                  final d =
                                  c.data() as Map<String, dynamic>;
                                  final uid = FirebaseAuth
                                      .instance.currentUser!.uid;
                                  final upvotes =
                                      (d["upvotes"] as List?) ?? [];
                                  final hasUpvoted =
                                  upvotes.contains(uid);

                                  return Container(
                                    margin:
                                    const EdgeInsets.only(top: 6),
                                    padding:
                                    const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius:
                                      BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                d["name"] ?? "Helper",
                                                style: const TextStyle(
                                                  fontWeight:
                                                  FontWeight.bold,
                                                ),
                                              ),
                                              Text(d["message"] ?? ""),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                hasUpvoted
                                                    ? Icons.thumb_up
                                                    : Icons
                                                    .thumb_up_outlined,
                                                color: hasUpvoted
                                                    ? Colors.blue
                                                    : Colors.grey,
                                              ),
                                              onPressed: () async {
                                                final ref =
                                                FirebaseFirestore
                                                    .instance
                                                    .collection("reports")
                                                    .doc(widget.reportId)
                                                    .collection(
                                                    "requirements")
                                                    .doc(req.id)
                                                    .collection(
                                                    "contributions")
                                                    .doc(c.id);

                                                if (hasUpvoted) {
                                                  await ref.update({
                                                    "upvotes":
                                                    FieldValue.arrayRemove(
                                                        [uid]),
                                                  });
                                                } else {
                                                  await ref.update({
                                                    "upvotes":
                                                    FieldValue.arrayUnion(
                                                        [uid]),
                                                  });
                                                }
                                              },
                                            ),
                                            Text(upvotes.length.toString()),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
