import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  final dynamic lat;
  final dynamic lng;
  final Map<String, dynamic>? reportData;

  const MapScreen({
    super.key,
    required this.lat,
    required this.lng,
    this.reportData,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  LatLng? _userLocation;
  LatLng? _disasterLocation;
  bool _loading = true;

  bool get _communityVerified => widget.reportData?['verified'] == true;

  bool get _authorityVerified {
    final role = (widget.reportData?['verifiedByRole'] ?? '').toString().toLowerCase();
    return role == 'ngo' || role == 'govt_authority';
  }

  bool get _aiSuspicious {
    final ai = widget.reportData?['aiAnalysis'];
    if (ai is! Map<String, dynamic>) return false;

    final isDisaster = ai['is_disaster'];
    final int matchScore = (ai['match_score'] ?? 0).toInt();
    final String alertType = (ai['alert_type'] ?? '').toString().toLowerCase();

    if (isDisaster == false) return true;
    if (matchScore < 5) return true;
    if (alertType.contains('suspicious')) return true;
    return false;
  }

  int get _aiScore {
    final ai = widget.reportData?['aiAnalysis'];
    if (ai is! Map<String, dynamic>) return 0;
    return (ai['match_score'] ?? 0).toInt();
  }

  Color _disasterColor() {
    if (_authorityVerified) return Colors.red;
    if (_aiSuspicious) return Colors.deepPurple;
    if (_communityVerified && _aiScore > 8) return Colors.red;
    if (_communityVerified && _aiScore < 8) return Colors.yellow.shade700;
    return Colors.orange;
  }

  String _statusLabel() {
    if (_authorityVerified) return 'Authority verified';
    if (_aiSuspicious) return 'Suspicious (awaiting NGO/authority verification)';
    if (_communityVerified && _aiScore > 8) return 'High risk: AI > 8 + community verified';
    if (_communityVerified && _aiScore < 8) return 'Moderate risk: AI < 8 + community verified';
    return 'Pending verification';
  }

  @override
  void initState() {
    super.initState();
    _initLocations();
  }

  Future<void> _initLocations() async {
    final lat = _toDouble(widget.lat);
    final lng = _toDouble(widget.lng);

    if (lat == null || lng == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    _disasterLocation = LatLng(lat, lng);

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.deniedForever && permission != LocationPermission.denied) {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        _userLocation = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _loading = false);
    _centerMap();
  }

  void _centerMap() {
    if (_disasterLocation == null) return;

    if (_userLocation != null) {
      final center = LatLng(
        (_userLocation!.latitude + _disasterLocation!.latitude) / 2,
        (_userLocation!.longitude + _disasterLocation!.longitude) / 2,
      );
      _mapController.move(center, 14);
    } else {
      _mapController.move(_disasterLocation!, 15);
    }
  }

  double? _distanceKm() {
    if (_userLocation == null || _disasterLocation == null) return null;

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_disasterLocation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Location')),
        body: const Center(child: Text('Location not available')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Disaster Location')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _disasterColor().withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _disasterColor()),
            ),
            child: Text(
              _statusLabel(),
              style: TextStyle(color: _disasterColor(), fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: _disasterLocation!, initialZoom: 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _disasterLocation!,
                      radius: 200,
                      useRadiusInMeter: true,
                      color: _disasterColor().withOpacity(0.2),
                      borderColor: _disasterColor(),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _disasterLocation!,
                      width: 40,
                      height: 40,
                      child: Icon(Icons.location_pin, color: _disasterColor(), size: 40),
                    ),
                    if (_userLocation != null)
                      Marker(
                        point: _userLocation!,
                        width: 35,
                        height: 35,
                        child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 35),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_distanceKm() != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                'Distance to disaster: ${_distanceKm()!.toStringAsFixed(2)} km',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          FloatingActionButton(
            onPressed: _centerMap,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
