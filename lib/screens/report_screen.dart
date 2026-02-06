import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../services/report_service.dart';

class ReportScreen extends StatefulWidget {
  final VoidCallback onReportSubmitted;

  const ReportScreen({
    super.key,
    required this.onReportSubmitted,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _service = ReportService();
  final _descController = TextEditingController();
  final _picker = ImagePicker();

  String? _type;
  double _severity = 3;
  double? _lat;
  double? _lng;
  List<File> _images = [];

  // ---------- HELPERS ----------

  Future<void> _pickImage() async {
    final file =
    await _picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      setState(() {
        _images.add(File(file.path));
      });
    }
  }

  Future<void> _getLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _lat = pos.latitude;
      _lng = pos.longitude;
    });
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= HEADER =================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade600,
                  Colors.red.shade800,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Report Incident",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Help others by reporting nearby incidents",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ================= TYPE =================
          Text(
            "Incident Type",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            children: ["Fire", "Flood", "Accident", "Earthquake"]
                .map(
                  (e) => ChoiceChip(
                label: Text(e),
                selected: _type == e,
                selectedColor: Colors.red.shade100,
                onSelected: (_) {
                  setState(() => _type = e);
                },
              ),
            )
                .toList(),
          ),

          const SizedBox(height: 22),

          // ================= DESCRIPTION =================
          Text(
            "Description",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _descController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "Describe what’s happening...",
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 22),

          // ================= MEDIA & LOCATION =================
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    _images.isEmpty
                        ? Icons.camera_alt
                        : Icons.check_circle,
                    color: _images.isEmpty
                        ? null
                        : Colors.green,
                  ),
                  label: Text(
                    _images.isEmpty
                        ? "Add Photo"
                        : "Photo Added",
                  ),
                  onPressed: _pickImage,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    _lat == null
                        ? Icons.location_on_outlined
                        : Icons.check_circle,
                    color:
                    _lat == null ? null : Colors.green,
                  ),
                  label: Text(
                    _lat == null
                        ? "Add Location"
                        : "Location Added",
                  ),
                  onPressed: _getLocation,
                ),
              ),
            ],
          ),

          if (_images.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _images.map((img) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        img,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 26),

          // ================= SEVERITY =================
          Text(
            "Severity",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),

          Slider(
            value: _severity,
            min: 1,
            max: 5,
            divisions: 4,
            label: _severity.toInt().toString(),
            onChanged: (v) {
              setState(() => _severity = v);
            },
          ),

          const SizedBox(height: 32),

          // ================= SUBMIT =================
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding:
                const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                "Submit Report",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                if (_type == null ||
                    _descController.text.isEmpty ||
                    _lat == null ||
                    _lng == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                      Text("Please complete all fields"),
                    ),
                  );
                  return;
                }

                await _service.addReport(
                  type: _type!,
                  description: _descController.text,
                  severity: _severity,
                  images:
                  _images.map((e) => e.path).toList(),
                  lat: _lat!,
                  lng: _lng!,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Report submitted"),
                  ),
                );

                widget.onReportSubmitted();
              },
            ),
          ),
        ],
      ),
    );
  }
}
