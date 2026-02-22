class Disaster {
  final String title;
  final String type;
  final double lat;
  final double lng;
  final DateTime date;
  final double? magnitude; // only for earthquakes

  Disaster({
    required this.title,
    required this.type,
    required this.lat,
    required this.lng,
    required this.date,
    this.magnitude,
  });
}