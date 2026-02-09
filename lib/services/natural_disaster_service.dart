import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/earthquake_model.dart';

class NaturalDisasterService {
  static const _url =
      "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson";

  Future<List<Earthquake>> fetchEarthquakes() async {
    final res = await http.get(Uri.parse(_url));

    if (res.statusCode != 200) {
      throw Exception("Failed to load earthquake data");
    }

    final data = json.decode(res.body);
    final List features = data["features"];

    return features
        .map((e) => Earthquake.fromJson(e))
        .where((q) {
      // 🇮🇳 INDIA BOUNDING BOX FILTER
      return q.lat >= 6.0 &&
          q.lat <= 37.5 &&
          q.lng >= 68.0 &&
          q.lng <= 97.5;
    })
        .toList();
  }

}
