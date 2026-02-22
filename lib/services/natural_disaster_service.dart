import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/disaster_model.dart';
import 'package:flutter/material.dart';


class NaturalDisasterService {
  static const _usgsUrl =
      "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson";

  static const _eonetUrl = "https://eonet.gsfc.nasa.gov/api/v3/events?days=20";

Future<List<Disaster>> fetchAllIndiaDisasters() async {
    final List<Disaster> disasters = [];

    try {
      // 1️⃣ Fetch Earthquakes (USGS)
      final eqRes = await http.get(Uri.parse(_usgsUrl));
      if (eqRes.statusCode == 200) {
        final eqData = json.decode(eqRes.body);
        final List features = eqData["features"] ?? [];
        for (var e in features) {
          final coords = e["geometry"]["coordinates"];
          final lat = coords[1].toDouble();
          final lng = coords[0].toDouble();
          if (_isIndia(lat, lng)) {
            disasters.add(Disaster(
              title: e["properties"]["place"] ?? "Unknown Earthquake",
              type: "Earthquake",
              lat: lat,
              lng: lng,
              magnitude: (e["properties"]["mag"] ?? 0).toDouble(),
              date: DateTime.fromMillisecondsSinceEpoch(e["properties"]["time"]),
            ));
          }
        }
      }

      // 2️⃣ Fetch Other Disasters (NASA EONET) - Added ?days=30 for testing
      final eonetRes = await http.get(Uri.parse(_eonetUrl));
      if (eonetRes.statusCode == 200) {
        final data = json.decode(eonetRes.body);
        final List events = data["events"] ?? [];

        for (var e in events) {
          final List geometries = e["geometry"] ?? [];
          if (geometries.isEmpty) continue;

          // Get the most recent geometry entry
          final geo = geometries.last;
          double? lat;
          double? lng;

          try {
            if (geo["type"] == "Point") {
              lng = geo["coordinates"][0].toDouble();
              lat = geo["coordinates"][1].toDouble();
            } else if (geo["type"] == "Polygon") {
              // Robust check for nested polygon arrays
              var coords = geo["coordinates"][0];
              while (coords[0] is List) {
                coords = coords[0];
              }
              lng = coords[0].toDouble();
              lat = coords[1].toDouble();
            }

            if (lat != null && lng != null && _isIndia(lat, lng)) {
              disasters.add(Disaster(
                title: e["title"] ?? "NASA Event",
                // EONET titles can be plural or specific, let's normalize
                type: e["categories"][0]["title"] ?? "General",
                lat: lat,
                lng: lng,
                date: DateTime.parse(geo["date"]),
              ));
            }
          } catch (err) {
            debugPrint("Error parsing EONET geometry: $err");
          }
        }
      }
    } catch (e) {
      debugPrint("General Service Error: $e");
    }

    // Sort by date so newest appears first
    disasters.sort((a, b) => b.date.compareTo(a.date));
    return disasters;
  }

  bool _isIndia(double lat, double lng) {
    return lat >= 6.0 &&
        lat <= 37.5 &&
        lng >= 68.0 &&
        lng <= 97.5;
  }
}