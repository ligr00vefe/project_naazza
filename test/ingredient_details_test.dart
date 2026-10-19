import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/features/records/presentation/ingredient_details_dialog.dart';

void main() {
  testWidgets(
    'old manufacturer wording shows ingredients with warning, without mutating record',
    (tester) async {
      final item = {
        'name': '뉴케어 당플랜 호두맛',
        'nutrition_source': {
          'reportNumber': '202104570283',
          'manufacturer': '구 업체',
        },
      };
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: IngredientDetailsDialog(
            item: item,
            fetcher: (report, company) async {
              calls++;
              expect(report, '202104570283');
              return {
                'status': 'ingredients',
                'companyVerified': false,
                'fromCache': true,
                'rows': [
                  {
                    'ingredientText': '대두,호두',
                    'company': '새 업체',
                    'changedAt': '20261015',
                  },
                ],
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('대두,호두'), findsOneWidget);
      expect(find.textContaining('업체명 표기가 기록과 달라요'), findsOneWidget);
      expect(
        (item['nutrition_source'] as Map).containsKey('ingredients'),
        false,
      );
    },
  );
  testWidgets(
    'legacy name-only record requires candidate selection before ingredient query',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: IngredientDetailsDialog(
            item: {'name': '제품'},
            lookup: (name) async => {
              'status': 'candidates',
              'candidates': [
                {
                  'name': '제품 200ml',
                  'reportNumber': '123456',
                  'manufacturer': '업체',
                },
              ],
            },
            fetcher: (report, company) async {
              calls++;
              return {'status': 'not_found'};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('제품 200ml'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('등록된 원재료 정보가 없어요'), findsOneWidget);
    },
  );
}
