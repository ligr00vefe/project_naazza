class FoodCandidate {
  const FoodCandidate({
    required this.name,
    required this.normalizedName,
    required this.confidence,
    required this.tags,
    required this.nutrition,
    this.amountG = 100,
  });

  final String name;
  final String normalizedName;
  final double confidence;
  final List<String> tags;
  final NutritionFacts nutrition;
  final double amountG;

  FoodCandidate copyWith({
    String? name,
    String? normalizedName,
    double? confidence,
    List<String>? tags,
    NutritionFacts? nutrition,
    double? amountG,
  }) => FoodCandidate(
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    confidence: confidence ?? this.confidence,
    tags: tags ?? this.tags,
    nutrition: nutrition ?? this.nutrition,
    amountG: amountG ?? this.amountG,
  );
}

class NutritionFacts {
  const NutritionFacts({
    required this.baseAmountG,
    required this.energyKcal,
    required this.carbohydrateG,
    required this.proteinG,
    required this.fatG,
    required this.sodiumMg,
  });

  final double baseAmountG;
  final double energyKcal;
  final double carbohydrateG;
  final double proteinG;
  final double fatG;
  final double sodiumMg;

  NutritionFacts forAmount(double amountG) {
    final ratio = baseAmountG <= 0 ? 0 : amountG / baseAmountG;
    return NutritionFacts(
      baseAmountG: amountG,
      energyKcal: energyKcal * ratio,
      carbohydrateG: carbohydrateG * ratio,
      proteinG: proteinG * ratio,
      fatG: fatG * ratio,
      sodiumMg: sodiumMg * ratio,
    );
  }
}

class MealAnalysisResult {
  const MealAnalysisResult({required this.photoPath, required this.foods});
  final String? photoPath;
  final List<FoodCandidate> foods;
}
