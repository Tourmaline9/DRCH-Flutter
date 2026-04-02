import 'package:flutter/material.dart';
import 'severity_chip.dart';

class DisasterCard extends StatelessWidget {
  final String title;

  const DisasterCard({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [

              Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SeverityChip(level: "High"),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [

                  TextButton.icon(
                    icon: const Icon(Icons.visibility),
                    label: const Text("View"),
                    onPressed: () {},
                  ),

                  TextButton.icon(
                    icon: const Icon(Icons.report),
                    label: const Text("Report"),
                    onPressed: () {},
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}