import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class NaturalMapScreen extends StatelessWidget {
  final List<Map<String, dynamic>> earthquakes;

  const NaturalMapScreen({
    super.key,
    required this.earthquakes,
  });

  @override
  Widget build(BuildContext context) {
    final markers = earthquakes.map((e) {
      final coords = e["geometry"]["coordinates"];
      final double lon = coords[0].toDouble();
      final double lat = coords[1].toDouble();

      final magRaw = e["properties"]["mag"];
      final double magnitude =
      (magRaw is num) ? magRaw.toDouble() : 0.0;

      return Marker(
        point: LatLng(lat, lon),
        width: 40,
        height: 40,
        child: Icon(
          Icons.circle,
          color: magnitude >= 5
              ? Colors.red
              : magnitude >= 4
              ? Colors.orange
              : Colors.yellow,
          size: 14 + magnitude * 2, // ✅ NOW VALID
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("India – Natural Disasters"),
      ),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(22.9734, 78.6569), // 🇮🇳 India center
          initialZoom: 4.5,
        ),
        children: [
          TileLayer(
            urlTemplate:
            "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.untitled',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}
