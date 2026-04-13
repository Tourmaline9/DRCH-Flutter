import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../widgets/empty_state.dart';
import '../widgets/loading_state.dart';
import 'incident_details_screen.dart';
import 'map_screen.dart';
import 'natural_map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<_WeatherData?> _weatherFuture;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _fetchCurrentWeather();
  }

  bool _isManMade(String type) {
    final t = type.toLowerCase();
    return t.contains('accident') ||
        t.contains('fire') ||
        t.contains('road') ||
        t.contains('riot') ||
        t.contains('explosion') ||
        t.contains('flood');
  }

  Color _severityColor(int s) {
    if (s >= 4) return Colors.red;
    if (s >= 2) return Colors.orange;
    return Colors.green;
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return '';

    if (timestamp is Timestamp) {
      final d = timestamp.toDate();
      return '${d.day.toString().padLeft(2, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.year} • '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }

    if (timestamp is int) {
      final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return '${d.day.toString().padLeft(2, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.year} • '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }

    return '';
  }

  Widget _buildImage(dynamic imageData) {
    if (imageData == null) return const SizedBox();

    try {
      if (imageData is String && !imageData.startsWith('/data/') && !imageData.startsWith('file:')) {
        return Image.memory(
          base64Decode(imageData),
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      }

      if (imageData is String) {
        final file = File(imageData);

        if (file.existsSync()) {
          return Image.file(
            file,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
          );
        }
      }
    } catch (_) {}

    return const SizedBox();
  }

  Future<List<Map<String, dynamic>>> _fetchIndiaEarthquakes() async {
    final url = Uri.parse(
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_week.geojson',
    );

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception('Failed to load earthquakes');
    }

    final data = json.decode(res.body);
    final List features = data['features'];

    return features.where((e) {
      final coords = e['geometry']['coordinates'];
      final lon = coords[0];
      final lat = coords[1];
      return lat >= 6 && lat <= 37 && lon >= 68 && lon <= 97;
    }).map((e) => e as Map<String, dynamic>).toList();
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<String?> _resolveCity(double lat, double lng) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=10&addressdetails=1',
    );

    final res = await http.get(
      uri,
      headers: const {
        'User-Agent': 'DRCH/1.0 (disaster-navigation)',
      },
    );

    if (res.statusCode != 200) return null;

    final body = json.decode(res.body) as Map<String, dynamic>;
    final address = body['address'] as Map<String, dynamic>?;

    if (address == null) return null;

    final city = address['city'] ?? address['town'] ?? address['village'] ?? address['county'];

    if (city is String && city.trim().isNotEmpty) {
      return city.trim().toLowerCase();
    }

    return null;
  }

  Future<_WeatherData?> _fetchCurrentWeather() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition();
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}&longitude=${pos.longitude}&current=temperature_2m,weather_code&timezone=auto',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) return null;

    final body = json.decode(res.body) as Map<String, dynamic>;
    final current = body['current'] as Map<String, dynamic>?;
    if (current == null) return null;

    final temperature = (current['temperature_2m'] as num?)?.toDouble();
    final code = (current['weather_code'] as num?)?.toInt() ?? -1;

    if (temperature == null) return null;
    return _WeatherData(temperature: temperature, description: _weatherCodeLabel(code), code: code);
  }

  String _weatherCodeLabel(int code) {
    if (code == 0) return 'Clear sky';
    if ([1, 2, 3].contains(code)) return 'Cloudy';
    if ([45, 48].contains(code)) return 'Fog';
    if ([51, 53, 55, 56, 57].contains(code)) return 'Drizzle';
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return 'Rain';
    if ([71, 73, 75, 77, 85, 86].contains(code)) return 'Snow';
    if ([95, 96, 99].contains(code)) return 'Thunderstorm';
    return 'Normal';
  }

  IconData _weatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if ([1, 2, 3].contains(code)) return Icons.cloud_rounded;
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return Icons.grain_rounded;
    if ([95, 96, 99].contains(code)) return Icons.thunderstorm_rounded;
    return Icons.wb_cloudy_rounded;
  }

  Future<void> _navigateToReportedDisaster(
    BuildContext context, {
    required dynamic lat,
    required dynamic lng,
  }) async {
    final destLat = _toDouble(lat);
    final destLng = _toDouble(lng);

    if (destLat == null || destLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available')),
      );
      return;
    }

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enable location to start navigation'),
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition();

      final userCity = await _resolveCity(pos.latitude, pos.longitude);
      final disasterCity = await _resolveCity(destLat, destLng);

      if (userCity == null || disasterCity == null || userCity != disasterCity) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Navigation is available only when you are in the same city as the reported disaster',
              ),
            ),
          );
        }
        return;
      }

      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=${pos.latitude},${pos.longitude}&destination=$destLat,$destLng&travelmode=driving',
      );

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open navigation')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start navigation')),
        );
      }
    }

    return;
  }

  Widget _weatherBar() {
    return FutureBuilder<_WeatherData?>(
      future: _weatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            dense: true,
            leading: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            title: Text('Getting your local weather...'),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const ListTile(
            dense: true,
            leading: Icon(Icons.cloud_off, color: Colors.white),
            title: Text('Weather unavailable', style: TextStyle(color: Colors.white)),
            subtitle: Text('Enable location to see local conditions.', style: TextStyle(color: Colors.white70)),
          );
        }

        final weather = snapshot.data!;
        return ListTile(
          dense: true,
          leading: Icon(_weatherIcon(weather.code), color: Colors.white),
          title: Text(
            '${weather.temperature.toStringAsFixed(1)}°C • ${weather.description}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Current weather at your location',
            style: TextStyle(color: Colors.white70),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Disasters',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.warning_amber_rounded), text: 'Reported'),
              Tab(icon: Icon(Icons.public), text: 'Natural (India)'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xff2f80ed), Color(0xff56ccf2)],
                    ),
                  ),
                  child: _weatherBar(),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('reports').orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingState(
                          message: 'Loading verified incidents...',
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const EmptyState(
                          icon: Icons.inbox,
                          title: 'No verified incidents',
                          subtitle: 'Nothing reported yet',
                        );
                      }

                      final docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['verified'] == true && _isManMade(data['type'] ?? '');
                      }).toList();

                      if (docs.isEmpty) {
                        return const EmptyState(
                          icon: Icons.verified_outlined,
                          title: 'No verified incidents',
                          subtitle: 'Nothing reported yet',
                        );
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              data['type'] ?? 'Unknown',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              _formatDateTime(data['createdAt']),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _severityColor(
                                            (data['severity'] ?? 1).toInt(),
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'S${data['severity']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (data['images'] != null && data['images'] is List && data['images'].isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: _buildImage(data['images'][0]),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(data['description'] ?? ''),
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.map_outlined),
                                        label: const Text('Location'),
                                        onPressed: () {
                                          if (data['lat'] == null || data['lng'] == null) return;

                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => MapScreen(
                                                lat: data['lat'],
                                                lng: data['lng'],
                                                reportData: data,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.navigation_outlined),
                                        label: const Text('Navigate'),
                                        onPressed: () {
                                          _navigateToReportedDisaster(
                                            context,
                                            lat: data['lat'],
                                            lng: data['lng'],
                                          );
                                        },
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.forum_outlined),
                                        label: const Text('Details'),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => IncidentDetailsScreen(
                                                reportId: doc.id,
                                                reportData: data,
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
                ),
              ],
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchIndiaEarthquakes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const EmptyState(
                    icon: Icons.public,
                    title: 'No recent disasters',
                    subtitle: 'No natural disasters in India this week',
                  );
                }

                final data = snapshot.data!;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.map),
                          label: const Text('View on Map'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NaturalMapScreen(
                                  earthquakes: data,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: data.length,
                        itemBuilder: (context, i) {
                          final p = data[i]['properties'];
                          final mag = (p['mag'] as num?)?.toDouble() ?? 0.0;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: Icon(
                                Icons.public,
                                color: mag >= 5
                                    ? Colors.red
                                    : mag >= 4
                                        ? Colors.orange
                                        : Colors.yellow,
                              ),
                              title: Text(p['place'] ?? 'Unknown location'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Magnitude: $mag'),
                                  Text(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      p['time'] ?? 0,
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

class _WeatherData {
  final double temperature;
  final String description;
  final int code;

  const _WeatherData({
    required this.temperature,
    required this.description,
    required this.code,
  });
}
