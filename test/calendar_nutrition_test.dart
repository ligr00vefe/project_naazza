import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/app/theme/app_theme.dart';
import 'package:naazza/features/auth/data/auth_repository.dart';
import 'package:naazza/features/auth/data/demo_auth_repository.dart';
import 'package:naazza/features/auth/domain/auth_user.dart';
import 'package:naazza/features/insights/domain/calendar_nutrition.dart';
import 'package:naazza/features/insights/domain/nutrient_intake.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/data/records_repository.dart';
import 'package:naazza/features/records/domain/health_record.dart';
import 'package:naazza/features/records/presentation/nutrition_mood_icon.dart';
import 'package:naazza/features/records/presentation/records_calendar_page.dart';

final person = AuthUser(
  id: 'demo-user',
  username: 'tester',
  birthDate: DateTime(1990),
  nutritionSex: 'male',
  nutritionLifeStage: 'general',
);
final now = DateTime.now();
DateTime date(int day) => DateTime(now.year, now.month, day, 9);
// Synthetic nutrient fixture; not the nutritional composition of a real food.
HealthRecord meal(
  int day,
  double ratio, {
  String category = 'breakfast',
  String suffix = '',
}) {
  final targets = KoreanNutrientReference.targets(person, date(day));
  return HealthRecord(
    id: 'meal-$day-$suffix',
    userId: 'demo-user',
    type: HealthRecordType.meal,
    recordedAt: date(day),
    title: '예시 식사',
    summary: '',
    data: {
      'meal_type': category,
      'items': [
        {
          'amount': 100,
          'amount_unit': 'g',
          'nutrition_source': {
            'basis': {'value': 100, 'unit': 'g'},
            'nutrition': {
              for (final e in targets.entries) e.key.publicKey: e.value * ratio,
            },
          },
        },
      ],
    },
  );
}

void main() {
  test('calendar mood boundaries include exact 90, 80 and 70 percent', () {
    for (final e in {
      1.2: NutritionMood.happy,
      .9: NutritionMood.happy,
      .899: NutritionMood.pleased,
      .8: NutritionMood.pleased,
      .799: NutritionMood.neutral,
      .7: NutritionMood.neutral,
      .699: NutritionMood.low,
      0.0: NutritionMood.low,
    }.entries) {
      final result = CalendarNutrition.fromRecords(
        [meal(1, e.key)],
        person,
        date(1),
      );
      expect(result.mood, e.value, reason: 'ratio ${e.key}');
      expect(result.knownCount, 11);
    }
  });
  test(
    'unknown values do not become zero and excess cannot offset other nutrients',
    () {
      final r = meal(1, 0);
      final source =
          ((r.data['items'] as List).first as Map)['nutrition_source'] as Map;
      source['nutrition'] = {
        'proteinG': 100000,
        'calciumMg': 0,
        'niacinMg': 9999,
      };
      final result = CalendarNutrition.fromRecords([r], person, date(1));
      expect(result.ratio, .5);
      expect(result.knownCount, 2);
      expect(result.targetCount, 11);
      expect(result.mood, NutritionMood.low);
      final partial = meal(1, 1, suffix: 'unknown').copyWith(data: {});
      expect(
        CalendarNutrition.fromRecords([r, partial], person, date(1)).ratio,
        isNull,
      );
      expect(
        CalendarNutrition.fromRecords([partial], person, date(1)).mood,
        NutritionMood.unknown,
      );
      expect(
        CalendarNutrition.fromRecords([], person, date(1)).hasMeals,
        false,
      );
      expect(CalendarNutrition.fromRecords([r], null, date(1)).ratio, isNull);
    },
  );
  test(
    'historical pregnancy data and days without meals never get a fabricated score',
    () {
      final pregnant = AuthUser(
        id: 'u',
        username: 'test',
        birthDate: DateTime(1990),
        nutritionSex: 'female',
        nutritionLifeStage: 'pregnant1',
      );
      final result = CalendarNutrition.fromRecords(
        [meal(1, 1)],
        pregnant,
        date(1),
        today: date(2),
      );
      expect(result.mood, NutritionMood.unknown);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'calendar stacks mood, alcohol/visit, distinct dots at scale $scale and preserves full-day score under meal filters',
      (tester) async {
        final preview =
            Platform.environment['UPDATE_CALENDAR_MOOD_PREVIEW'] == '1' &&
            scale == 1;
        tester.view.physicalSize = preview
            ? const Size(393, 1100)
            : const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (preview) {
          await tester.runAsync(() async {
            final bytes = await File(
              'C:/Windows/Fonts/malgun.ttf',
            ).readAsBytes();
            await (FontLoader(
              'PreviewKorean',
            )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
            final icons = await File(
              'C:/utils/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
            ).readAsBytes();
            await (FontLoader(
              'MaterialIcons',
            )..addFont(Future.value(ByteData.sublistView(icons)))).load();
          });
        }
        final auth = DemoAuthRepository(), repo = DemoRecordsRepository();
        await tester.runAsync(
          () => auth.signIn(username: 'tester', pin: '1234'),
        );
        await auth.updateNutritionProfile(
          birthDate: person.birthDate,
          sex: 'male',
          lifeStage: 'general',
        );
        for (final entry in {1: .9, 2: .8, 3: .7, 4: .69}.entries) {
          await repo.create(meal(entry.key, entry.value));
        }
        await repo.create(meal(1, 0, category: 'snack', suffix: 'snack'));
        await repo.create(meal(5, 0).copyWith(data: {}));
        for (final type in [
          HealthRecordType.alcohol,
          HealthRecordType.visit,
          HealthRecordType.bowel,
          HealthRecordType.condition,
        ]) {
          await repo.create(
            HealthRecord(
              id: type.name,
              userId: 'demo-user',
              type: type,
              recordedAt: date(1),
              title: '예시 기록',
              summary: '',
              data: {},
            ),
          );
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(auth),
              recordsRepositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              theme: preview
                  ? AppTheme.light.copyWith(
                      textTheme: AppTheme.light.textTheme.apply(
                        fontFamily: 'PreviewKorean',
                      ),
                    )
                  : AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const RepaintBoundary(
                key: ValueKey('calendar-mood-preview'),
                child: RecordsCalendarPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        NutritionMood mood(int day) => tester
            .widget<NutritionMoodIcon>(
              find.byKey(ValueKey('nutrition-mood-$day')),
            )
            .mood;
        expect(mood(1), NutritionMood.happy);
        expect(mood(2), NutritionMood.pleased);
        expect(mood(3), NutritionMood.neutral);
        expect(mood(4), NutritionMood.low);
        expect(mood(5), NutritionMood.unknown);
        expect(find.byKey(const ValueKey('nutrition-mood-6')), findsNothing);
        final face = find.byKey(const ValueKey('nutrition-mood-1'));
        final alcohol = find.byKey(const ValueKey('alcohol-marker-1'));
        final visit = find.byKey(const ValueKey('visit-marker-1'));
        final bowel = find.byKey(const ValueKey('bowel-marker-1'));
        final condition = find.byKey(const ValueKey('condition-marker-1'));
        expect(
          tester.getCenter(face).dy,
          lessThan(tester.getCenter(alcohol).dy),
        );
        expect(tester.getCenter(alcohol).dy, tester.getCenter(visit).dy);
        expect(
          tester.getCenter(visit).dy,
          lessThan(tester.getCenter(bowel).dy),
        );
        expect(
          tester.widget<Icon>(bowel).color,
          isNot(tester.widget<Icon>(condition).color),
        );
        expect(
          tester
              .widget<Icon>(
                find.descendant(of: face, matching: find.byType(Icon)),
              )
              .size,
          16,
        );
        expect(tester.takeException(), isNull);
        if (preview) {
          for (final e in find.byType(RichText).evaluate()) {
            final p = e.renderObject! as RenderParagraph,
                s = p.text as TextSpan;
            if (s.style?.fontFamily == 'MaterialIcons') continue;
            p.text = TextSpan(
              text: s.text,
              children: s.children,
              style: (s.style ?? const TextStyle()).copyWith(
                fontFamily: 'PreviewKorean',
              ),
            );
          }
          await tester.pump();
          final b = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('calendar-mood-preview')),
          );
          await tester.runAsync(() async {
            final img = await b.toImage(pixelRatio: 2),
                bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            await File(
              'artifacts/calendar-nutrition-mood-preview.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('calendar-filter')),
        );
        await tester.tap(find.byKey(const ValueKey('calendar-filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, '아침만 보기'));
        await tester.pumpAndSettle();
        final toggle = find.widgetWithText(CheckboxListTile, '검진 기록 표시하기');
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        final done = find.widgetWithText(FilledButton, '완료');
        await tester.ensureVisible(done);
        await tester.tap(done);
        await tester.pumpAndSettle();
        expect(mood(1), NutritionMood.happy);
        expect(visit, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
