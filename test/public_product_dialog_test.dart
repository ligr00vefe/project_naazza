import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/features/meal_analysis/domain/meal_analysis.dart';
import 'package:naazza/features/meal_analysis/presentation/public_product_dialog.dart';

const photo = IdentifiedProduct(
  name: '테스트 제품',
  amountText: '200ml',
  energyKcal: 200,
);
Map<String, dynamic> product(String id, {double size = 200}) => {
  'id': id,
  'name': '테스트 제품',
  'manufacturer': '테스트 제조사',
  'packageSizeText': '${size.round()}ml',
  'basisText': '100ml',
  'basis': {'value': 100, 'unit': 'ml'},
  'packageSize': {'value': size, 'unit': 'ml'},
  'nutrition': {'energyKcal': 100},
  'source': {'recordId': id, 'referenceDate': '2026-10-01'},
};
Future<void> open(
  WidgetTester tester,
  PublicProductLookup lookup, {
  VoidCallback? onManual,
  IngredientLookup? ingredientLookup,
  ValueChanged<FoodCandidate?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            child: const Text('열기'),
            onPressed: () async {
              final result = await showDialog<FoodCandidate>(
                context: context,
                builder: (_) => PublicProductDialog(
                  photo: photo,
                  lookup: lookup,
                  onManual: onManual,
                  ingredientLookup: ingredientLookup,
                ),
              );
              onResult?.call(result);
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'ingredient view does not store raw ingredients in meal metadata',
    (tester) async {
      FoodCandidate? selected;
      final candidate = product('with-ingredients');
      candidate['reportNumber'] = '123456789';
      await open(
        tester,
        (query, page) async => {
          'status': 'candidates',
          'candidates': [candidate],
        },
        ingredientLookup: (report, company) async => {
          'status': 'ingredients',
          'companyVerified': true,
          'hasMore': false,
          'rows': [
            {'ingredientText': '대두, 밀'},
          ],
          'allergyStatus': 'unknown',
        },
        onResult: (value) => selected = value,
      );
      await tester.tap(find.text('원재료 정보 확인'));
      await tester.pumpAndSettle();
      expect(find.textContaining('알레르기 표시·같은 시설 제조 정보는 미확인'), findsOneWidget);
      await tester.ensureVisible(find.text('현재 제품과 같아요'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('현재 제품과 같아요'));
      await tester.pumpAndSettle();
      expect(selected!.nutritionSource!.containsKey('ingredients'), false);
    },
  );

  testWidgets(
    'missing configuration is not product absence and manual action is immediate',
    (tester) async {
      var manual = false, calls = 0;
      await open(tester, (query, page) async {
        calls++;
        return {'status': 'not_configured'};
      }, onManual: () => manual = true);
      expect(find.textContaining('연결 설정'), findsOneWidget);
      expect(find.textContaining('등록된 제품을 찾지'), findsNothing);
      expect(calls, 1);
      await tester.tap(find.text('사진 첨부해 직접 입력'));
      await tester.pumpAndSettle();
      expect(manual, true);
      expect(calls, 1);
    },
  );
  testWidgets(
    'same name different package cannot be selected; matching candidate requires explicit tap',
    (tester) async {
      FoodCandidate? selected;
      await open(
        tester,
        (query, page) async => {
          'status': 'candidates',
          'candidates': [product('wrong', size: 300), product('right')],
          'hasMore': false,
        },
        onResult: (value) => selected = value,
      );
      expect(selected, isNull);
      expect(find.textContaining('자동 적용할 수 없어요'), findsOneWidget);
      final buttons = tester
          .widgetList<TextButton>(find.widgetWithText(TextButton, '현재 제품과 같아요'))
          .toList();
      expect(buttons.first.onPressed, isNull);
      expect(buttons.last.onPressed, isNotNull);
      await tester.ensureVisible(find.text('현재 제품과 같아요').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('현재 제품과 같아요').last);
      await tester.pumpAndSettle();
      expect(selected!.wholeCalories, 200);
      expect(
        (selected!.nutritionSource!['source'] as Map)['recordId'],
        'right',
      );
    },
  );
  testWidgets(
    'transport failure permits user retry without automatic request loop',
    (tester) async {
      var calls = 0;
      await open(tester, (query, page) async {
        calls++;
        throw TimeoutException('test');
      });
      expect(calls, 1);
      expect(find.textContaining('지연'), findsOneWidget);
      await tester.tap(find.text('다시 조회'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    },
  );
  testWidgets('pagination requests next page only after user action', (
    tester,
  ) async {
    final pages = <int>[];
    await open(tester, (query, page) async {
      pages.add(page);
      return {
        'status': 'candidates',
        'candidates': [product('p$page')],
        'hasMore': page == 1,
      };
    });
    expect(pages, [1]);
    await tester.ensureVisible(find.text('다른 후보 더 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다른 후보 더 보기'));
    await tester.pumpAndSettle();
    expect(pages, [1, 2]);
    expect(find.text('다른 후보 더 보기'), findsNothing);
  });
  testWidgets(
    'editable product name and adjusted query are retained for pagination',
    (tester) async {
      final queries = <String>[];
      await open(tester, (query, page) async {
        queries.add(query);
        if (query == photo.name) {
          return {'status': 'not_found', 'candidates': []};
        }
        return {
          'status': 'candidates',
          'candidates': [product('p$page')],
          'searchedQuery': '크라운산도 밤티라미수',
          'searchAdjusted': true,
          'hasMore': page == 1,
        };
      });
      await tester.enterText(find.byType(TextField), '크라운 산도 밤티라미수');
      await tester.tap(find.text('제품명으로 검색'));
      await tester.pumpAndSettle();
      expect(find.textContaining('검색 표기 보정:'), findsOneWidget);
      await tester.ensureVisible(find.text('다른 후보 더 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다른 후보 더 보기'));
      await tester.pumpAndSettle();
      expect(queries, [photo.name, '크라운 산도 밤티라미수', '크라운산도 밤티라미수']);
    },
  );
}
