import 'package:flutter/material.dart';
import '../services/natural_disaster_service.dart';
import '../models/earthquake_model.dart';
import 'map_screen.dart';

class NaturalDisasterScreen extends StatelessWidget {
  const NaturalDisasterScreen({super.key});

  String _formatTime(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return "${d.day}/${d.month}/${d.year} "
        "${d.hour}:${d.minute.toString().padLeft(2, '0')}";
  }

  Color _magColor(double mag) {
    if (mag >= 5) return Colors.red;
    if (mag >= 3) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Earthquake>>(
      future: NaturalDisasterService().fetchEarthquakes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text("Failed to load natural disasters"),
          );
        }

        final quakes = snapshot.data!;

        if (quakes.isEmpty) {
          return const Center(
            child: Text("No recent natural disasters in India"),
          );
        }

        return ListView.builder(
          itemCount: quakes.length,
          itemBuilder: (context, i) {
            final q = quakes[i];

            return Card(
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _magColor(q.magnitude),
                  child: Text(
                    q.magnitude.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(q.place),
                subtitle: Text(
                  "Time: ${_formatTime(q.time)}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.map),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapScreen(
                          lat: q.lat,
                          lng: q.lng,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
