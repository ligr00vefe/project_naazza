import 'package:flutter/material.dart';
import '../domain/meal_group.dart';

class MealCategorySelector extends StatelessWidget {
  const MealCategorySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final category in MealCategory.values)
        ChoiceChip(
          key: ValueKey('meal-category-${category.value}'),
          label: Text(category.label),
          selected: MealCategory.fromValue(value) == category,
          onSelected: (_) => onChanged(category.value),
        ),
    ],
  );
}
