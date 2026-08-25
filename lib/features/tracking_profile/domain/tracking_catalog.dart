import 'package:flutter/material.dart';

class TrackingMetricDefinition {
  const TrackingMetricDefinition({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

class ConditionDefinition {
  const ConditionDefinition({
    required this.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.metricKeys,
  });
  final String key;
  final String label;
  final String subtitle;
  final IconData icon;
  final List<String> metricKeys;
}

abstract final class TrackingCatalog {
  static const metrics = <TrackingMetricDefinition>[
    TrackingMetricDefinition(
      key: 'blood_glucose',
      label: '혈당',
      icon: Icons.water_drop_rounded,
      color: Color(0xFFFF7777),
    ),
    TrackingMetricDefinition(
      key: 'carbohydrate',
      label: '탄수화물',
      icon: Icons.rice_bowl_rounded,
      color: Color(0xFF51A891),
    ),
    TrackingMetricDefinition(
      key: 'meal_time',
      label: '식사시간',
      icon: Icons.schedule_rounded,
      color: Color(0xFFF3B33E),
    ),
    TrackingMetricDefinition(
      key: 'bowel',
      label: '배변',
      icon: Icons.circle_rounded,
      color: Color(0xFFC27B35),
    ),
    TrackingMetricDefinition(
      key: 'abdominal_pain',
      label: '복통',
      icon: Icons.sick_rounded,
      color: Color(0xFF8B68D5),
    ),
    TrackingMetricDefinition(
      key: 'bloating',
      label: '복부팽만',
      icon: Icons.sentiment_dissatisfied_rounded,
      color: Color(0xFFA56FC8),
    ),
    TrackingMetricDefinition(
      key: 'fatigue',
      label: '피로',
      icon: Icons.bedtime_rounded,
      color: Color(0xFF6C86C9),
    ),
    TrackingMetricDefinition(
      key: 'fat',
      label: '지방',
      icon: Icons.opacity_rounded,
      color: Color(0xFFF0B83F),
    ),
    TrackingMetricDefinition(
      key: 'meal_amount',
      label: '식사량',
      icon: Icons.restaurant_rounded,
      color: Color(0xFF57A584),
    ),
    TrackingMetricDefinition(
      key: 'diarrhea',
      label: '설사',
      icon: Icons.water_drop_outlined,
      color: Color(0xFF55A9E8),
    ),
    TrackingMetricDefinition(
      key: 'sodium',
      label: '나트륨',
      icon: Icons.science_rounded,
      color: Color(0xFF619DD7),
    ),
    TrackingMetricDefinition(
      key: 'potassium',
      label: '칼륨',
      icon: Icons.eco_rounded,
      color: Color(0xFFE9B52E),
    ),
    TrackingMetricDefinition(
      key: 'phosphorus',
      label: '인',
      icon: Icons.hexagon_rounded,
      color: Color(0xFFF1B848),
    ),
    TrackingMetricDefinition(
      key: 'water_intake',
      label: '수분',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF54A9EE),
    ),
  ];

  static const conditions = <ConditionDefinition>[
    ConditionDefinition(
      key: 'diabetes',
      label: '당뇨 / 혈당 관리',
      subtitle: '혈당과 탄수화물 중심',
      icon: Icons.water_drop_outlined,
      metricKeys: ['blood_glucose', 'carbohydrate', 'meal_time'],
    ),
    ConditionDefinition(
      key: 'ibd',
      label: '크론병 / 궤양성 대장염',
      subtitle: '배변과 복부 증상 중심',
      icon: Icons.medical_information_outlined,
      metricKeys: ['bowel', 'abdominal_pain', 'bloating', 'fatigue'],
    ),
    ConditionDefinition(
      key: 'post_cholecystectomy',
      label: '담낭 절제 후 관리',
      subtitle: '지방과 설사 반응 중심',
      icon: Icons.eco_outlined,
      metricKeys: ['fat', 'meal_amount', 'diarrhea', 'abdominal_pain'],
    ),
    ConditionDefinition(
      key: 'kidney',
      label: '신장 건강 / 투석 관리',
      subtitle: '전해질과 수분 중심',
      icon: Icons.settings_input_component_rounded,
      metricKeys: ['sodium', 'potassium', 'phosphorus', 'water_intake'],
    ),
    ConditionDefinition(
      key: 'custom',
      label: '기타 / 직접 설정',
      subtitle: '필요한 항목을 직접 선택',
      icon: Icons.tune_rounded,
      metricKeys: [],
    ),
  ];

  static TrackingMetricDefinition metric(String key) =>
      metrics.firstWhere((metric) => metric.key == key);
}
