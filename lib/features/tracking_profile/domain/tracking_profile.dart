class TrackingMetricSelection {
  const TrackingMetricSelection({
    required this.metricKey,
    required this.enabled,
    required this.quickLogOrder,
  });

  final String metricKey;
  final bool enabled;
  final int quickLogOrder;

  TrackingMetricSelection copyWith({bool? enabled, int? quickLogOrder}) =>
      TrackingMetricSelection(
        metricKey: metricKey,
        enabled: enabled ?? this.enabled,
        quickLogOrder: quickLogOrder ?? this.quickLogOrder,
      );
}

class TrackingProfile {
  const TrackingProfile({
    required this.conditionKeys,
    required this.metrics,
    required this.remindersEnabled,
  });

  final List<String> conditionKeys;
  final List<TrackingMetricSelection> metrics;
  final bool remindersEnabled;
}
