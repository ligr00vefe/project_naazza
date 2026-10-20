import 'photo_failure.dart';

class FoodCandidate {
  const FoodCandidate({
    required this.name,
    required this.normalizedName,
    required this.confidence,
    required this.tags,
    required this.nutrition,
    this.amountG = 100,
    this.amountUnit = 'g',
    this.hasCompleteNutrition = true,
    this.isProduct = false,
    this.quantity = 1,
    this.portioned = false,
    this.totalAmountG,
    this.nutritionSource,
  });

  final Map<String, dynamic>? nutritionSource;
  final String name;
  final String normalizedName;
  final double confidence;
  final List<String> tags;
  final NutritionFacts nutrition;
  final double amountG;
  final String amountUnit;
  final bool hasCompleteNutrition;
  final bool isProduct;
  final int quantity;
  double get consumedAmountG => amountG * (isProduct ? quantity : 1);
  NutritionFacts get consumedNutrition => nutrition.forAmount(consumedAmountG);
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
    String? amountUnit,
    bool? hasCompleteNutrition,
    bool? isProduct,
    int? quantity,
    bool? portioned,
    double? totalAmountG,
  }) => FoodCandidate(
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    confidence: confidence ?? this.confidence,
    tags: tags ?? this.tags,
    nutrition: nutrition ?? this.nutrition,
    amountG: amountG ?? this.amountG,
    amountUnit: amountUnit ?? this.amountUnit,
    hasCompleteNutrition: hasCompleteNutrition ?? this.hasCompleteNutrition,
    isProduct: isProduct ?? this.isProduct,
    quantity: quantity ?? this.quantity,
    portioned: portioned ?? this.portioned,
    totalAmountG: totalAmountG ?? this.totalAmountG,
    nutritionSource: nutritionSource,
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

  double? _recordNutrient(
    String field,
    double currentValue, {
    bool sourceOnly = false,
  }) {
    if (hasCompleteNutrition && !sourceOnly) return currentValue;
    final source = nutritionSource;
    final values = source?['nutrition'];
    final basis = source?['basis'];
    if (values is! Map || basis is! Map) return null;
    final raw = values[field], base = basis['value'];
    if (raw is! num ||
        !raw.isFinite ||
        raw < 0 ||
        base is! num ||
        !base.isFinite ||
        base <= 0) {
      return null;
    }
    return raw.toDouble() * nutrition.baseAmountG / base.toDouble();
  }

  Map<String, Object?> toRecordItem({String? sourceType}) => {
    'name': name,
    'normalized_name': normalizedName,
    'nutrition_source': ?(nutritionSource == null
        ? null
        : (Map<String, dynamic>.from(nutritionSource!)..remove('ingredients'))),
    'amount': consumedAmountG,
    'amount_unit': amountUnit,
    'amount_g': amountUnit == 'g' ? consumedAmountG : null,
    'unit_amount': amountG,
    'unit_amount_g': amountUnit == 'g' ? amountG : null,
    'is_product': isProduct,
    'quantity': isProduct ? quantity : 1,
    'tags': tags,
    'confidence': confidence,
    'nutrition_known': !tags.contains('열량미기록'),
    'source_type': ?sourceType,
    'portioned': portioned,
    'total_amount': wholeAmountG,
    'total_amount_g': amountUnit == 'g' ? wholeAmountG : null,
    'macronutrients_known': hasCompleteNutrition,
    'total_energy_kcal': wholeCalories,
    'nutrition': {
      'base_amount': nutrition.baseAmountG,
      'amount_unit': amountUnit,
      'base_amount_g': amountUnit == 'g' ? nutrition.baseAmountG : null,
      'energy_kcal': nutrition.energyKcal,
      'carbohydrate_g': _recordNutrient(
        'carbohydrateG',
        nutrition.carbohydrateG,
      ),
      'protein_g': _recordNutrient('proteinG', nutrition.proteinG),
      'fat_g': _recordNutrient('fatG', nutrition.fatG),
      'sodium_mg': _recordNutrient('sodiumMg', nutrition.sodiumMg),
      for (final entry in const {
        'calcium_mg': 'calciumMg',
        'iron_mg': 'ironMg',
        'vitamin_c_mg': 'vitaminC',
        'vitamin_d_ug': 'vitaminD',
        'fiber_g': 'fiberG',
        'potassium_mg': 'potassiumMg',
        'phosphorus_mg': 'phosphorusMg',
        'vitamin_a_rae': 'vitaminA',
        'thiamin_mg': 'thiaminMg',
        'riboflavin_mg': 'riboflavinMg',
        'niacin_mg': 'niacinMg',
      }.entries)
        entry.key: nutritionSource == null
            ? null
            : _recordNutrient(entry.value, 0, sourceOnly: true),
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

class IdentifiedProduct {
  const IdentifiedProduct({
    required this.name,
    this.amountText = '',
    this.energyKcal,
    this.confidence = 0.85,
  });
  final String name;
  final String amountText;
  final double? energyKcal;
  final double confidence;
  static IdentifiedProduct? tryFromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final confidence = json['confidence'];
    if (name is! String ||
        name.trim().isEmpty ||
        confidence is! num ||
        !confidence.isFinite ||
        confidence < 0.85) {
      return null;
    }
    final energy = json['energyKcal'];
    return IdentifiedProduct(
      name: name.trim(),
      confidence: confidence.toDouble().clamp(0, 1),
      amountText: json['amountText'] is String
          ? (json['amountText'] as String).trim()
          : '',
      energyKcal: energy is num && energy.isFinite && energy >= 0
          ? energy.toDouble()
          : null,
    );
  }
}

class MealAnalysisResult {
  const MealAnalysisResult({
    required this.photoPath,
    required this.foods,
    this.failure,
    this.identifiedProducts = const [],
  });
  final List<IdentifiedProduct> identifiedProducts;
  final PhotoFailure? failure;
  final String? photoPath;
  final List<FoodCandidate> foods;
}
