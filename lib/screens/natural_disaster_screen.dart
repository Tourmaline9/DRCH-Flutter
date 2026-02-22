import 'package:flutter/material.dart';
import '../services/natural_disaster_service.dart';
import '../models/disaster_model.dart';
import 'map_screen.dart';

class NaturalDisasterScreen extends StatelessWidget {
  const NaturalDisasterScreen({super.key});

  Color _typeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains("earthquake")) return Colors.red;
    if (t.contains("flood")) return Colors.blue;
    if (t.contains("wildfire")) return Colors.orange;
    if (t.contains("storm")) return Colors.purple;
    // ... and so on
    return Colors.teal;
  }
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Disaster>>(
      future: NaturalDisasterService()
          .fetchAllIndiaDisasters(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
              child: Text("Failed to load disasters"));
        }

        final disasters = snapshot.data!;

        if (disasters.isEmpty) {
          return const Center(
              child: Text("No active disasters in India"));
        }

        return ListView.builder(
          itemCount: disasters.length,
          itemBuilder: (context, i) {
            final d = disasters[i];

            return Card(
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                  _typeColor(d.type),
                  child: d.magnitude != null
                      ? Text(
                    d.magnitude!
                        .toStringAsFixed(1),
                    style:
                    const TextStyle(
                      color: Colors.white,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  )
                      : const Icon(
                    Icons.warning,
                    color: Colors.white,
                  ),
                ),
                title: Text(d.title),
                subtitle: Text(
                    "${d.type}\n${d.date.toLocal()}"),
                trailing: IconButton(
                  icon:
                  const Icon(Icons.map),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MapScreen(
                              lat: d.lat,
                              lng: d.lng,
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