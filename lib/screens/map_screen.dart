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
    final double? lat = _toDouble(widget.lat);
    final double? lng = _toDouble(widget.lng);

    if (lat == null || lng == null) {
      setState(() => _loading = false);
      return;
    }

    _disasterLocation = LatLng(lat, lng);

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

    _centerMap();
  }

  // ---------------- CENTER ----------------

  void _centerMap() {
    if (_disasterLocation == null) return;

    if (_userLocation != null) {
      final center = LatLng(
        (_userLocation!.latitude +
            _disasterLocation!.latitude) /
            2,
        (_userLocation!.longitude +
            _disasterLocation!.longitude) /
            2,
      );

      _mapController.move(center, 14);
    } else {
      _mapController.move(_disasterLocation!, 15);
    }
  }

  // ---------------- HELPERS ----------------

  double? _distanceKm() {
    if (_userLocation == null || _disasterLocation == null) {
      return null;
    }

    final meters = Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      _disasterLocation!.latitude,
      _disasterLocation!.longitude,
    );

    return meters / 1000;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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

          // 🗺️ Map Tiles
          TileLayer(
            urlTemplate:
            "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.untitled',
          ),

          if (_userLocation != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [_userLocation!, _disasterLocation!],
                  strokeWidth: 4,
                  color: Colors.blue,
                ),
              ],
            ),

          // 🔴 200M RADIUS CIRCLE
          CircleLayer(
            circles: [
              CircleMarker(
                point: _disasterLocation!,
                radius: 200, // 200 meters
                useRadiusInMeter: true,
                color: Colors.red.withOpacity(0.2),
                borderColor: Colors.red,
                borderStrokeWidth: 2,
              ),
            ],
          ),

          // 📍 MARKERS
          MarkerLayer(
            markers: [

              // 🚨 Disaster marker
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

              // 👤 User marker
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

      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_distanceKm() != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                "Distance to disaster: ${_distanceKm()!.toStringAsFixed(2)} km",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          FloatingActionButton(
            child: const Icon(Icons.my_location),
            onPressed: _centerMap,
          ),
        ],
      ),
    );
  }
}
