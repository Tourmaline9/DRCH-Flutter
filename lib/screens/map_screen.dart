import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {

  final dynamic lat;
  final dynamic lng;

  const MapScreen({
    super.key,
    required this.lat,
    required this.lng,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {

  final MapController _mapController = MapController();

  LatLng? _userLocation;
  LatLng? _disasterLocation;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initLocations();
  }

  // ---------------- INIT ----------------

  Future<void> _initLocations() async {
    // Convert disaster coords
    final double? lat = _toDouble(widget.lat);
    final double? lng = _toDouble(widget.lng);

    if (lat == null || lng == null) {
      setState(() => _loading = false);
      return;
    }

    _disasterLocation = LatLng(lat, lng);

    // Get user location
    try {
      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.deniedForever &&
          permission != LocationPermission.denied) {
        final pos =
        await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        _userLocation =
            LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}

    setState(() => _loading = false);

    // Center map
    _centerMap();
  }

  // ---------------- CENTER ----------------

  void _centerMap() {
    if (_disasterLocation == null) return;

    // If user location available → center between both
    if (_userLocation != null) {
      final center = LatLng(
        (_userLocation!.latitude +
            _disasterLocation!.latitude) /
            2,
        (_userLocation!.longitude +
            _disasterLocation!.longitude) /
            2,
      );

      _mapController.move(center, 13);
    } else {
      // Otherwise center on disaster
      _mapController.move(_disasterLocation!, 15);
    }
  }
// ---------------- HELPERS ----------------

  double? _toDouble(dynamic value) {

    if (value == null) return null;

    if (value is double) return value;

    if (value is int) return value.toDouble();

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_disasterLocation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Location")),
        body: const Center(
          child: Text("Location not available"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Disaster Location"),
      ),

      body: FlutterMap(

        mapController: _mapController,

        options: MapOptions(
          initialCenter: _disasterLocation!,
          initialZoom: 15,
        ),

        children: [

          // 🗺️ OSM Tiles
          TileLayer(
            urlTemplate:
            "https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png",

            subdomains: const ['a', 'b', 'c'],

            userAgentPackageName: 'com.example.untitled',
          ),


          // 📍 Markers
          MarkerLayer(
            markers: [

              // 🚨 Disaster marker (RED)
              Marker(
                point: _disasterLocation!,

                width: 40,
                height: 40,

                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),

              // 👤 User marker (BLUE)
              if (_userLocation != null)
                Marker(
                  point: _userLocation!,

                  width: 35,
                  height: 35,

                  child: const Icon(
                    Icons.person_pin_circle,
                    color: Colors.blue,
                    size: 35,
                  ),
                ),
            ],
          ),
        ],
      ),

      // 🔘 Recenter Button
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.my_location),

        onPressed: _centerMap,
      ),
    );
  }
}