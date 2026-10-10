class FoodCandidate {
  const FoodCandidate({
    required this.name,
    required this.normalizedName,
    required this.confidence,
    required this.tags,
    required this.nutrition,
    this.amountG = 100,
    this.portioned = false,
    this.totalAmountG,
  });

  final String name;
  final String normalizedName;
  final double confidence;
  final List<String> tags;
  final NutritionFacts nutrition;
  final double amountG;
  final bool portioned;
  final double? totalAmountG;
  double get wholeAmountG => totalAmountG ?? amountG;
  double get wholeCalories => nutrition.forAmount(wholeAmountG).energyKcal;

  FoodCandidate copyWith({
    String? name,
    String? normalizedName,
    double? confidence,
    List<String>? tags,
    NutritionFacts? nutrition,
    double? amountG,
    bool? portioned,
    double? totalAmountG,
  }) => FoodCandidate(
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    confidence: confidence ?? this.confidence,
    tags: tags ?? this.tags,
    nutrition: nutrition ?? this.nutrition,
    amountG: amountG ?? this.amountG,
    portioned: portioned ?? this.portioned,
    totalAmountG: totalAmountG ?? this.totalAmountG,
  );
  FoodCandidate withPortion({
    required double totalG,
    required double totalKcal,
    required double consumedG,
    required bool enabled,
  }) {
    if (!totalG.isFinite ||
        totalG <= 0 ||
        !totalKcal.isFinite ||
        totalKcal < 0 ||
        !consumedG.isFinite ||
        consumedG <= 0 ||
        (enabled && consumedG > totalG)) {
      throw ArgumentError('전체 용량과 먹은 양을 확인해 주세요.');
    }
    final whole = nutrition.forAmount(totalG);
    return copyWith(
      portioned: enabled,
      totalAmountG: totalG,
      amountG: consumedG,
      nutrition: NutritionFacts(
        baseAmountG: totalG,
        energyKcal: totalKcal,
        carbohydrateG: whole.carbohydrateG,
        proteinG: whole.proteinG,
        fatG: whole.fatG,
        sodiumMg: whole.sodiumMg,
      ),
    );
  }

  Map<String, Object?> toRecordItem({String? sourceType}) => {
    'name': name,
    'normalized_name': normalizedName,
    'amount_g': amountG,
    'tags': tags,
    'confidence': confidence,
    'nutrition_known': !tags.contains('열량미기록'),
    'source_type': ?sourceType,
    'portioned': portioned,
    'total_amount_g': wholeAmountG,
    'total_energy_kcal': wholeCalories,
    'nutrition': {
      'base_amount_g': nutrition.baseAmountG,
      'energy_kcal': nutrition.energyKcal,
      'carbohydrate_g': nutrition.carbohydrateG,
      'protein_g': nutrition.proteinG,
      'fat_g': nutrition.fatG,
      'sodium_mg': nutrition.sodiumMg,
    },
  };
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
