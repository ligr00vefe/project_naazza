import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../records/domain/health_record.dart';
import '../../records/presentation/records_controller.dart';

class VisitRecents {
  const VisitRecents({this.facilities = const [], this.departments = const []});
  final List<String> facilities, departments;
  static List<String> _remember(List<String> values, String input, int limit) {
    final value = input.trim();
    if (value.isEmpty) return values;
    return [value, ...values.where((old) => old != value)].take(limit).toList();
  }

  VisitRecents remember(String facility, String department) => VisitRecents(
    facilities: _remember(facilities, facility, 3),
    departments: _remember(departments, department, 5),
  );
  VisitRecents removeFacility(String value) => VisitRecents(
    facilities: facilities.where((old) => old != value).toList(),
    departments: departments,
  );
  VisitRecents removeDepartment(String value) => VisitRecents(
    facilities: facilities,
    departments: departments.where((old) => old != value).toList(),
  );
  factory VisitRecents.fromRecords(
    Iterable<HealthRecord> records,
    String? userId,
  ) {
    final visits =
        records
            .where(
              (r) => r.userId == userId && r.type == HealthRecordType.visit,
            )
            .toList()
          ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return visits.fold(
      const VisitRecents(),
      (recent, record) => recent.remember(
        record.data['facility_label']?.toString() ?? '',
        record.data['department']?.toString() ?? '',
      ),
    );
  }
}

class VisitRecentsController extends Notifier<VisitRecents> {
  bool _seeded = false;
  @override
  VisitRecents build() {
    final userId = ref.watch(
      authStateProvider.select((auth) => auth.value?.id),
    );
    _seeded = false;
    ref.listen(recordsProvider, (_, next) {
      if (!_seeded && next.hasValue) {
        _seeded = true;
        state = VisitRecents.fromRecords(next.value ?? [], userId);
      }
    });
    final records = ref.read(recordsProvider);
    if (records.hasValue) {
      _seeded = true;
      return VisitRecents.fromRecords(records.value ?? [], userId);
    }
    return const VisitRecents();
  }

  void remember(String facility, String department) {
    state = state.remember(facility, department);
  }

  void removeFacility(String value) {
    state = state.removeFacility(value);
  }

  void removeDepartment(String value) {
    state = state.removeDepartment(value);
  }
}

final visitRecentsProvider =
    NotifierProvider<VisitRecentsController, VisitRecents>(
      VisitRecentsController.new,
    );
