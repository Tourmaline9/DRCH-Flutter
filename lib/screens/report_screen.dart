import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../services/report_service.dart';

/// ---------------- STATE ----------------
class ReportFormState {
  final String? type;
  final double severity;
  final double? lat;
  final double? lng;
  final List<File> images;
  final bool submitting;

  const ReportFormState({
    this.type,
    this.severity = 3,
    this.lat,
    this.lng,
    this.images = const [],
    this.submitting = false,
  });

  ReportFormState copyWith({
    String? type,
    double? severity,
    double? lat,
    double? lng,
    List<File>? images,
    bool? submitting,
  }) {
    return ReportFormState(
      type: type ?? this.type,
      severity: severity ?? this.severity,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      images: images ?? this.images,
      submitting: submitting ?? this.submitting,
    );
  }
}

/// ---------------- NOTIFIER ----------------
class ReportFormNotifier extends StateNotifier<ReportFormState> {
  ReportFormNotifier() : super(const ReportFormState());

  void setType(String value) => state = state.copyWith(type: value);
  void setLocation(double lat, double lng) =>
      state = state.copyWith(lat: lat, lng: lng);
  void addImage(File image) =>
      state = state.copyWith(images: [...state.images, image]);
  void setSeverity(double value) =>
      state = state.copyWith(severity: value);
  void setSubmitting(bool value) =>
      state = state.copyWith(submitting: value);
  void reset() => state = const ReportFormState();
}

final reportFormProvider =
StateNotifierProvider.autoDispose<ReportFormNotifier, ReportFormState>(
        (ref) => ReportFormNotifier());

/// ---------------- UI ----------------
class ReportScreen extends ConsumerStatefulWidget {
  final VoidCallback onReportSubmitted;

  const ReportScreen({super.key, required this.onReportSubmitted});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _service = ReportService();
  final _descController = TextEditingController();
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      ref.read(reportFormProvider.notifier).addImage(File(file.path));
    }
  }

  Future<void> _getLocation() async {
    final pos = await Geolocator.getCurrentPosition();
    ref
        .read(reportFormProvider.notifier)
        .setLocation(pos.latitude, pos.longitude);
  }

  Future<void> _submitReport() async {
    final state = ref.read(reportFormProvider);

    if (state.type == null ||
        _descController.text.trim().isEmpty ||
        state.lat == null ||
        state.images.isEmpty) {
      _show('Please complete all fields');
      return;
    }

    ref.read(reportFormProvider.notifier).setSubmitting(true);

    try {
      await _service.addReport(
        type: state.type!,
        description: _descController.text.trim(),
        severity: state.severity,
        images: state.images,
        lat: state.lat!,
        lng: state.lng!,
        aiAnalysis: {},
      );

      _show('Report submitted successfully');
      widget.onReportSubmitted();
      ref.read(reportFormProvider.notifier).reset();
      _descController.clear();
    } catch (_) {
      _show('Failed to submit report');
    } finally {
      ref.read(reportFormProvider.notifier).setSubmitting(false);
    }
  }

  void _show(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Color _severityColor(double val) {
    if (val <= 2) return Colors.green;
    if (val <= 3) return Colors.orange;
    return Colors.red;
  }

  String _severityText(double val) {
    if (val <= 2) return "Low";
    if (val <= 3) return "Moderate";
    if (val <= 4) return "High";
    return "Critical";
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportFormProvider);

    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xffFF416C), Color(0xffFF4B2B)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.report, color: Colors.white, size: 28),
                  SizedBox(width: 10),
                  Text(
                    "Report Incident",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// INCIDENT TYPE
            Text("Incident Type",
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: ['Fire', 'Flood', 'Accident', 'Earthquake']
                  .map((e) => ChoiceChip(
                label: Text(e),
                selected: state.type == e,
                selectedColor: Colors.red.shade100,
                onSelected: (_) =>
                    ref.read(reportFormProvider.notifier).setType(e),
              ))
                  .toList(),
            ),

            const SizedBox(height: 20),

            /// DESCRIPTION
            _card(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.description, color: Colors.red),
                    const SizedBox(width: 8),
                    Text("Description",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: "Describe what’s happening in detail...",
                    border: InputBorder.none,
                  ),
                ),
              ],
            )),

            const SizedBox(height: 20),

            /// SEVERITY
            _card(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text("Severity Level",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Low"),
                    Text(
                      _severityText(state.severity),
                      style: TextStyle(
                          color: _severityColor(state.severity),
                          fontWeight: FontWeight.bold),
                    ),
                    const Text("Critical"),
                  ],
                ),
                Slider(
                  value: state.severity,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: _severityColor(state.severity),
                  onChanged: (v) =>
                      ref.read(reportFormProvider.notifier).setSeverity(v),
                ),
              ],
            )),

            const SizedBox(height: 20),

            /// ACTION BUTTONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Photo"),
                    onPressed: _pickImage,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.location_on),
                    label: const Text("Location"),
                    onPressed: _getLocation,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// IMAGE PREVIEW
            if (state.images.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: state.images
                      .map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(e,
                          width: 80, fit: BoxFit.cover),
                    ),
                  ))
                      .toList(),
                ),
              ),

            const SizedBox(height: 28),

            /// SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.submitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                child: state.submitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "Submit Report",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}