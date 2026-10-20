import 'package:flutter/material.dart';
import '../../records/domain/health_record.dart';
import 'observation_dashboard.dart';

/// Shared observation dashboard retained under the original card entry point.
class HealthPatternCard extends StatelessWidget {
  const HealthPatternCard({super.key, required this.records});
  final List<HealthRecord> records;
  @override
  Widget build(BuildContext context) => ObservationDashboard(records: records);
}
