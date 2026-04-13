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
  void setSeverity(double value) => state = state.copyWith(severity: value);
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
  bool _injured = false;

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
        aiAnalysis: {
          'injured': _injured,
        },
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

  void _show(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportFormProvider);
    final incidentTypes = [
      ('Mountain\nOn Fire', Icons.landscape_outlined),
      ('Forest\nOn Fire', Icons.park_outlined),
      ('Building\nOn Fire', Icons.apartment_outlined),
      ('Others', Icons.add),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: 330,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xffe7eef8), Color(0xffd8e8f7)],
              ),
            ),
          ),
          Positioned(
            top: 80,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.lightBlue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.red),
                      SizedBox(width: 6),
                      Text(
                        'FIRE SHIELD',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 170),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('What Happen?', style: TextStyle(fontSize: 28)),
                        Text('What is on fire select any of these.', style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 12),
                        Row(
                          children: incidentTypes
                              .map(
                                (incident) => Expanded(
                                  child: GestureDetector(
                                    onTap: () => ref
                                        .read(reportFormProvider.notifier)
                                        .setType(incident.$1.replaceAll('\n', ' ')),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: state.type == incident.$1.replaceAll('\n', ' ')
                                            ? const Color(0xffffecec)
                                            : const Color(0xfff1f3f6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(incident.$2, color: Colors.black87),
                                          const SizedBox(height: 6),
                                          Text(
                                            incident.$1,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 12, height: 1.1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.camera_alt, color: Colors.red),
                            label: const Text('Can you take some pictures?'),
                            onPressed: _pickImage,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    Row(
                      children: [
                        const Icon(Icons.health_and_safety_outlined),
                        const SizedBox(width: 8),
                        const Text('Any injured?', style: TextStyle(fontSize: 17)),
                        const Spacer(),
                        ChoiceChip(
                          label: const Text('Yes'),
                          selected: _injured,
                          onSelected: (_) => setState(() => _injured = true),
                          selectedColor: Colors.green,
                          labelStyle: TextStyle(color: _injured ? Colors.white : null),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('No'),
                          selected: !_injured,
                          onSelected: (_) => setState(() => _injured = false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    Column(
                      children: [
                        TextField(
                          controller: _descController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Explain us more (Optional)',
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.location_on_outlined),
                            label: Text(state.lat == null ? 'Use my location' : 'Location captured'),
                            onPressed: _getLocation,
                          ),
                        ),
                        if (state.images.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 70,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: state.images
                                  .map((e) => Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.file(e, width: 70, fit: BoxFit.cover),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
                        Slider(
                          value: state.severity,
                          min: 1,
                          max: 5,
                          divisions: 4,
                          activeColor: Colors.red,
                          onChanged: (v) => ref.read(reportFormProvider.notifier).setSeverity(v),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: state.submitting ? null : _submitReport,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: state.submitting
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Send Fire Report',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
