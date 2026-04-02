import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../services/report_service.dart';

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
    bool clearType = false,
    bool clearLocation = false,
  }) {
    return ReportFormState(
      type: clearType ? null : (type ?? this.type),
      severity: severity ?? this.severity,
      lat: clearLocation ? null : (lat ?? this.lat),
      lng: clearLocation ? null : (lng ?? this.lng),
      images: images ?? this.images,
      submitting: submitting ?? this.submitting,
    );
  }
}

class ReportFormNotifier extends StateNotifier<ReportFormState> {
  ReportFormNotifier() : super(const ReportFormState());

  void setType(String value) => state = state.copyWith(type: value);
  void setLocation(double lat, double lng) => state = state.copyWith(lat: lat, lng: lng);
  void addImage(File image) => state = state.copyWith(images: [...state.images, image]);
  void setSubmitting(bool value) => state = state.copyWith(submitting: value);
  void reset() => state = const ReportFormState();
}

final reportFormProvider = StateNotifierProvider.autoDispose<ReportFormNotifier, ReportFormState>((ref) {
  return ReportFormNotifier();
});

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
    try {
      final file = await _picker.pickImage(source: ImageSource.camera);
      if (file != null) {
        ref.read(reportFormProvider.notifier).addImage(File(file.path));
      }
    } catch (_) {
      _show('Camera permission required');
    }
  }

  Future<void> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _show('Location service is disabled');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _show('Location permission required');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      ref.read(reportFormProvider.notifier).setLocation(pos.latitude, pos.longitude);
    } catch (_) {
      _show('Unable to get location');
    }
  }

  Future<void> _submitReport() async {
    final state = ref.read(reportFormProvider);
    if (state.type == null ||
        _descController.text.trim().isEmpty ||
        state.lat == null ||
        state.lng == null ||
        state.images.isEmpty) {
      _show('Please complete all fields including photo');
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

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportFormProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.red.shade600, Colors.red.shade800]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Report Incident', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Help others by reporting nearby incidents', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
        ),
        const SizedBox(height: 24),
        Text('Incident Type', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: ['Fire', 'Flood', 'Accident', 'Earthquake']
              .map((e) => ChoiceChip(
                    label: Text(e),
                    selected: state.type == e,
                    selectedColor: Colors.red.shade100,
                    onSelected: (_) => ref.read(reportFormProvider.notifier).setType(e),
                  ))
              .toList(),
        ),
        const SizedBox(height: 22),
        Text('Description', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        TextField(
          controller: _descController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe what’s happening...',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: Icon(state.images.isEmpty ? Icons.camera_alt : Icons.check_circle,
                  color: state.images.isEmpty ? null : Colors.green),
              label: Text(state.images.isEmpty ? 'Add Photo' : 'Photo Added'),
              onPressed: _pickImage,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: Icon(state.lat == null ? Icons.location_on_outlined : Icons.check_circle,
                  color: state.lat == null ? null : Colors.green),
              label: Text(state.lat == null ? 'Add Location' : 'Location Added'),
              onPressed: _getLocation,
            ),
          ),
        ]),
        if (state.images.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: state.images
                  .map((img) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(img, width: 80, height: 80, fit: BoxFit.cover),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: state.submitting ? null : _submitReport,
            child: state.submitting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}
