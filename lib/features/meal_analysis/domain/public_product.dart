import 'meal_analysis.dart';
import 'photo_food_resolution.dart';

class PublicProduct {
  PublicProduct(this.data);
  final Map<String, dynamic> data;
  bool get isProduct => data['dataCode'] == null || data['dataCode'] == 'P';
  String get name => data['name'] as String? ?? '';
  String get manufacturer {
    final maker = data['manufacturer'] as String? ?? '';
    return maker.isNotEmpty ? maker : data['company'] as String? ?? '';
  }

  String get packageText => data['packageSizeText'] as String? ?? '';
  String get basisText => data['basisText'] as String? ?? '';
  String get referenceDate =>
      (data['source'] as Map?)?['referenceDate']?.toString() ?? '';
  double? value(Object? raw) =>
      raw is num && raw.isFinite && raw >= 0 ? raw.toDouble() : null;
  FoodCandidate? confirmedFood(IdentifiedProduct photo) {
    final basis = data['basis'];
    final nutrition = data['nutrition'];
    if (basis is! Map || nutrition is! Map) return null;
    final base = value(basis['value']), energy = value(nutrition['energyKcal']);
    final unit = basis['unit'];
    if (base == null ||
        base <= 0 ||
        energy == null ||
        !['g', 'ml'].contains(unit)) {
      return null;
    }
    final size = data['packageSize'];
    final photographed = productAmount(photo.amountText);
    double? total = size is Map && size['unit'] == unit
        ? value(size['value'])
        : null;
    // A known package quantity in another unit is a conflict, not missing data.
    if (size is Map && size['unit'] != unit) return null;
    if (photographed != null) {
      if (photographed.unit != unit ||
          (total != null && (total - photographed.amount).abs() > 0.01)) {
        return null;
      }
      total = photographed.amount;
    }
    if (total == null || total <= 0) return null;
    final calculated = energy * total / base;
    if (photo.energyKcal != null &&
        (photo.energyKcal! - calculated).abs() > 1) {
      return null;
    }
    final complete = [
      'carbohydrateG',
      'proteinG',
      'fatG',
      'sodiumMg',
    ].every((key) => value(nutrition[key]) != null);
    return FoodCandidate(
      name: name,
      normalizedName: name,
      confidence: photo.confidence,
      tags: ['공공데이터 · 정보 확인', if (!complete) '일부 영양성분 미확인'],
      isProduct: isProduct,
      amountG: total,
      amountUnit: unit as String,
      hasCompleteNutrition: complete,
      nutritionSource: Map<String, dynamic>.from(data),
      nutrition: NutritionFacts(
        baseAmountG: base,
        energyKcal: energy,
        carbohydrateG: value(nutrition['carbohydrateG']) ?? 0,
        proteinG: value(nutrition['proteinG']) ?? 0,
        fatG: value(nutrition['fatG']) ?? 0,
        sodiumMg: value(nutrition['sodiumMg']) ?? 0,
      ),
    );
  }
}
