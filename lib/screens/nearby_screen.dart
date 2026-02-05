import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/report_service.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {

  final ReportService _service = ReportService();

  final MapController _mapController = MapController();

  List<Marker> _markers = [];

  // Default: Delhi
  LatLng _center = const LatLng(28.6139, 77.2090);

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  // ---------------- LOAD MARKERS ----------------
  Future<void> _loadMarkers() async {

    try {

      // Get verified reports once
      final snapshot = await FirebaseFirestore.instance
          .collection("reports")
          .where("verified", isEqualTo: true)
          .get();

      final List<Marker> temp = [];

      for (var doc in snapshot.docs) {

        final data = doc.data();

        if (data["lat"] != null && data["lng"] != null) {

          final double lat = data["lat"].toDouble();
          final double lng = data["lng"].toDouble();

          final pos = LatLng(lat, lng);

          temp.add(
            Marker(
              width: 40,
              height: 40,

              point: pos,

              child: const Icon(
                Icons.location_pin,
                color: Colors.red,
                size: 40,
              ),
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _markers = temp; // ✅ FIXED
        _loading = false;
      });

    } catch (e) {

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nearby Disasters"),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(

        mapController: _mapController,

        options: MapOptions(
          initialCenter: _center,
          initialZoom: 12,
        ),

        children: [

          // 🗺️ MAP TILES (HOT SERVER - Better)
          TileLayer(
            urlTemplate:
            "https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png",

            subdomains: const ['a', 'b', 'c'],

            userAgentPackageName: 'com.example.untitled',
          ),


          // 📍 MARKERS
          MarkerLayer(
            markers: _markers,
          ),
        ],
      ),
    );
  }
}
