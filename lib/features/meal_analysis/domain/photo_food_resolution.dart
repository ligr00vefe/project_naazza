import 'meal_analysis.dart';

String _key(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[\s\-_()]'), '');
double? _positive(Object? value) {
  final n = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  return n != null && n.isFinite && n > 0 ? n : null;
}

({double amount, String unit})? productAmount(String text) {
  final match = RegExp(
    r'^\s*(\d+(?:\.\d+)?)\s*(kg|g|ml|l|그램|밀리리터|리터)\s*$',
    caseSensitive: false,
  ).firstMatch(text.replaceAll(',', ''));
  if (match == null) return null;
  final amount = _positive(match[1]);
  if (amount == null) return null;
  final unit = match[2]!.toLowerCase();
  return (
    amount: amount * (unit == 'kg' || unit == 'l' || unit == '리터' ? 1000 : 1),
    unit: ['ml', 'l', '리터', '밀리리터'].contains(unit) ? 'ml' : 'g',
  );
}

FoodCandidate? foodFromProductLabel(IdentifiedProduct product) {
  final kcal = product.energyKcal;
  if (kcal == null || !kcal.isFinite || kcal < 0) return null;
  final amount = productAmount(product.amountText) ?? (amount: 1.0, unit: '개');
  return _calorieFood(product, amount.amount, amount.unit, kcal, '표시 열량 확인');
}

FoodCandidate _calorieFood(
  IdentifiedProduct product,
  double amount,
  String unit,
  double kcal,
  String source,
) => FoodCandidate(
  name: product.name,
  normalizedName: product.name,
  confidence: product.confidence,
  tags: [source, '다른 영양성분 미확인'],
  isProduct: true,
  amountG: amount,
  amountUnit: unit,
  hasCompleteNutrition: false,
  nutrition: NutritionFacts(
    baseAmountG: amount,
    energyKcal: kcal,
    carbohydrateG: 0,
    proteinG: 0,
    fatG: 0,
    sodiumMg: 0,
  ),
);

MealAnalysisResult resolvePhotoFoods(MealAnalysisResult result) {
  final foods = result.foods.toList(), pending = <IdentifiedProduct>[];
  for (final product in result.identifiedProducts) {
    if (foods.any((food) => _key(food.name) == _key(product.name))) continue;
    final candidate = foodFromProductLabel(product);
    if (candidate != null) {
      foods.add(candidate);
    } else {
      pending.add(product);
    }
  }
  return MealAnalysisResult(
    photoPath: result.photoPath,
    foods: foods,
    identifiedProducts: pending,
    failure: foods.isEmpty ? result.failure : null,
  );
}
