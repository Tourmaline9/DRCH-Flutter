import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

final nearbyMarkersProvider = FutureProvider.autoDispose<List<Marker>>((ref) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('reports')
      .where('verified', isEqualTo: true)
      .get();

  return snapshot.docs
      .where((doc) => doc.data()['lat'] != null && doc.data()['lng'] != null)
      .map((doc) {
        final data = doc.data();
        return Marker(
          width: 40,
          height: 40,
          point: LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble()),
          child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
        );
      })
      .toList();
});

class NearbyScreen extends ConsumerWidget {
  const NearbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const center = LatLng(28.6139, 77.2090);
    final markersAsync = ref.watch(nearbyMarkersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Disasters')),
      body: markersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (markers) => FlutterMap(
          options: const MapOptions(initialCenter: center, initialZoom: 12),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.untitled',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }
}
