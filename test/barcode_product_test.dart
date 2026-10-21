import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:naazza/features/meal_analysis/data/supabase_meal_analysis_repository.dart';

void main() {
  test('바코드 음료는 ml로 계산하고 없는 영양소는 0 대신 미확인으로 저장한다', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'product': {
            'displayName': '테스트 음료',
            'amountG': 1800,
            'amountUnit': 'ml',
            'isProduct': true,
            'hasCompleteNutrition': false,
            'tags': ['일부 영양정보 미등록'],
            'nutrition': {
              'baseAmountG': 100,
              'energyKcal': 0,
              'proteinG': null,
            },
            'nutritionSource': {
              'basis': {'value': 100, 'unit': 'ml'},
              'nutrition': {
                'energyKcal': 0,
                'carbohydrateG': 0,
                'proteinG': null,
                'fatG': 0,
                'sodiumMg': null,
              },
            },
          },
        }),
      );
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
    );
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });
    final product = await SupabaseMealAnalysisRepository(
      client,
    ).lookupBarcode('8801056251154');
    expect(product!.amountUnit, 'ml');
    expect(product.amountG, 1800);
    expect(product.consumedNutrition.energyKcal, 0);
    final item = product.toRecordItem(sourceType: 'barcode');
    expect(item['amount_unit'], 'ml');
    expect(item['amount_g'], isNull);
    final nutrition = item['nutrition'] as Map;
    expect(nutrition['protein_g'], isNull);
    expect(nutrition['sodium_mg'], isNull);
    expect(nutrition['carbohydrate_g'], 0);
  });
}
