import 'package:flutter/material.dart';

class SeverityChip extends StatelessWidget {
  final String level;

  const SeverityChip({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    Color color;

    if (level == "High") {
      color = Colors.red;
    } else if (level == "Medium") {
      color = Colors.orange;
    } else {
      color = Colors.green;
    }

    return Chip(
      backgroundColor: color.withOpacity(0.2),
      label: Text(
        level,
        style: TextStyle(color: color),
      ),
    );
  }
}
