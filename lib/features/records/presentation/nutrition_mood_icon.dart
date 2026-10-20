import 'package:flutter/material.dart';
import '../../insights/domain/calendar_nutrition.dart';

class NutritionMoodIcon extends StatelessWidget {
  const NutritionMoodIcon({super.key, required this.mood});
  final NutritionMood mood;

  @override
  Widget build(BuildContext context) => Icon(
    switch (mood) {
      NutritionMood.happy => Icons.sentiment_very_satisfied_rounded,
      NutritionMood.pleased => Icons.sentiment_satisfied_alt_rounded,
      NutritionMood.neutral => Icons.sentiment_neutral_rounded,
      NutritionMood.low => Icons.sentiment_dissatisfied_rounded,
      NutritionMood.unknown => Icons.help_outline_rounded,
    },
    size: 16,
    color: switch (mood) {
      NutritionMood.happy => const Color(0xFF387748),
      NutritionMood.pleased => const Color(0xFF689234),
      NutritionMood.neutral => const Color(0xFFB08025),
      NutritionMood.low => const Color(0xFFB56C58),
      NutritionMood.unknown => const Color(0xFF8C9690),
    },
  );
}
