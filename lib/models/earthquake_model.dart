class Earthquake {
  final String place;
  final double magnitude;
  final int time;
  final double lat;
  final double lng;

  Earthquake({
    required this.place,
    required this.magnitude,
    required this.time,
    required this.lat,
    required this.lng,
  });

  factory Earthquake.fromJson(Map<String, dynamic> json) {
    return Earthquake(
      place: json["properties"]["place"],
      magnitude:
      (json["properties"]["mag"] ?? 0).toDouble(),
      time: json["properties"]["time"],
      lat: json["geometry"]["coordinates"][1],
      lng: json["geometry"]["coordinates"][0],
    );
  }
}
