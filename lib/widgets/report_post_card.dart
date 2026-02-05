import 'dart:io';
import 'package:flutter/material.dart';

class ReportPostCard extends StatelessWidget {
  final String description;
  final String type;
  final int severity;
  final String? imagePath;
  final VoidCallback onMapTap;

  const ReportPostCard({
    super.key,
    required this.description,
    required this.type,
    required this.severity,
    this.imagePath,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              description,
              style: const TextStyle(fontSize: 16),
            ),
          ),

          if (imagePath != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: Image.file(
                File(imagePath!),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),

          ListTile(
            title: Text(type),
            subtitle: Text("Severity: $severity"),
            trailing: IconButton(
              icon: const Icon(Icons.map),
              onPressed: onMapTap,
            ),
          ),
        ],
      ),
    );
  }
}
