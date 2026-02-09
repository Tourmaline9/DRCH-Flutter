import 'package:flutter/foundation.dart';

class DisasterReport {
  final String type;
  final String description;
  final double severity;
  final List<String> imagePaths;
  final DateTime time;

  final double latitude;
  final double longitude;

  bool verified;

  DisasterReport({
    required this.type,
    required this.description,
    required this.severity,
    required this.imagePaths,
    required this.time,

    required this.latitude,
    required this.longitude,

    this.verified = false,
  });
}


class ReportStore {
  static final ReportStore _instance = ReportStore._internal();

  factory ReportStore() => _instance;

  ReportStore._internal();

  final List<DisasterReport> _reports = [];

  // Notifier for UI refresh
  final ValueNotifier<int> notifier = ValueNotifier(0);

  List<DisasterReport> get reports => _reports;

  void addReport(DisasterReport report) {
    _reports.add(report);
    notifier.value++;
  }

  void removeReport(DisasterReport report) {
    _reports.remove(report);
    notifier.value++;
  }

  void verifyReport(DisasterReport report) {
    report.verified = true;
    notifier.value++;
  }

  List<DisasterReport> get unverifiedReports =>
      _reports.where((r) => !r.verified).toList();
}
