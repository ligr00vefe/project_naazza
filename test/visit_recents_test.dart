import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/features/records/data/demo_records_repository.dart';
import 'package:naazza/features/records/domain/health_record.dart';
import 'package:naazza/features/visits/presentation/visit_recents.dart';
import 'meal_timeline_test.dart' show open;

HealthRecord visit(int index, {DateTime? next}) => HealthRecord(
  id: 'visit-$index',
  userId: 'demo-user',
  type: HealthRecordType.visit,
  recordedAt: DateTime(2026, 10, index),
  title: '병원$index',
  summary: '진료',
  data: {
    'facility_label': '병원$index',
    'department': '진료과$index',
    if (next != null) 'next_visit_at': next.toIso8601String(),
  },
);
void main() {
  test('최근 병원 3개와 진료과 5개는 중복 없이 최신 입력 순으로 제한한다', () {
    var recent = const VisitRecents();
    for (var index = 1; index <= 7; index++) {
      recent = recent.remember('병원$index', '진료과$index');
    }
    expect(recent.facilities, ['병원7', '병원6', '병원5']);
    expect(recent.departments, ['진료과7', '진료과6', '진료과5', '진료과4', '진료과3']);
    recent = recent.remember(' 병원6 ', '진료과4');
    expect(recent.facilities, ['병원6', '병원7', '병원5']);
    expect(recent.departments.first, '진료과4');
    recent = recent.removeFacility('병원6').removeDepartment('진료과4');
    expect(recent.facilities, ['병원7', '병원5']);
    expect(recent.departments.contains('진료과4'), false);
    expect(
      VisitRecents.fromRecords([visit(1), visit(2)], 'another-user').facilities,
      isEmpty,
    );
  });
  testWidgets('최근 입력은 필드 위에서 선택하고 삭제하며 화면을 다시 열어도 세션에서 유지된다', (tester) async {
    final repo = DemoRecordsRepository();
    for (var index = 1; index <= 7; index++) {
      await repo.create(visit(index));
    }
    final router = await open(tester, repo, location: '/record/visit');
    addTearDown(router.dispose);
    final chips = tester
        .widgetList<InputChip>(find.byType(InputChip))
        .map((chip) => (chip.label as Text).data)
        .toList();
    expect(chips, [
      '병원7',
      '병원6',
      '병원5',
      '진료과7',
      '진료과6',
      '진료과5',
      '진료과4',
      '진료과3',
    ]);
    await tester.ensureVisible(find.byKey(const ValueKey('visit-facility')));
    expect(
      tester.getTopLeft(find.widgetWithText(InputChip, '병원7')).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('visit-facility'))).dy,
      ),
    );
    await tester.tap(find.widgetWithText(InputChip, '병원6'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('visit-facility')))
          .controller
          ?.text,
      '병원6',
    );
    await tester.ensureVisible(find.widgetWithText(InputChip, '진료과5'));
    await tester.tap(find.widgetWithText(InputChip, '진료과5'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('visit-department')))
          .controller
          ?.text,
      '진료과5',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(InputChip, '병원7'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, '병원7'),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/home');
    await tester.pumpAndSettle();
    router.go('/record/visit');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, '병원7'), findsNothing);
    expect((await repo.list('demo-user')).length, 7);
    await tester.enterText(
      find.byKey(const ValueKey('visit-facility')),
      '새 병원',
    );
    await tester.enterText(
      find.byKey(const ValueKey('visit-department')),
      '새 진료과',
    );
    await tester.tap(find.byKey(const ValueKey('visit-save')));
    await tester.pumpAndSettle();
    router.go('/record/visit');
    await tester.pumpAndSettle();
    expect(
      (tester.widget<InputChip>(find.byType(InputChip).first).label as Text)
          .data,
      '새 병원',
    );
    expect(find.widgetWithText(InputChip, '새 진료과'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('키보드 위에 저장 버튼이 보이고 스크롤하면 키보드 포커스가 해제된다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final repo = DemoRecordsRepository(),
        record = visit(1, next: DateTime.now().add(const Duration(days: 30)));
    await repo.create(record);
    final router = await open(
      tester,
      repo,
      location: '/record/visit',
      initialRecord: record,
    );
    addTearDown(router.dispose);
    await tester.ensureVisible(find.byKey(const ValueKey('visit-facility')));
    await tester.showKeyboard(find.byKey(const ValueKey('visit-facility')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(
      tester.getBottomRight(find.byKey(const ValueKey('visit-save'))).dy,
      lessThanOrEqualTo(544),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    final editable = find.descendant(
      of: find.byKey(const ValueKey('visit-facility')),
      matching: find.byType(EditableText),
    );
    if (editable.evaluate().isNotEmpty) {
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, false);
    }
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('visit-reminder')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final nextBottom = tester
            .getBottomRight(find.byKey(const ValueKey('visit-next-date')))
            .dy,
        reminderTop = tester
            .getTopLeft(find.byKey(const ValueKey('visit-reminder')))
            .dy;
    expect(reminderTop - nextBottom, greaterThanOrEqualTo(16));
    expect(find.textContaining('(선택)'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
