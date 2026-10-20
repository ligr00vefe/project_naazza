import 'package:flutter_test/flutter_test.dart';
import 'package:naazza/features/auth/domain/birth_date.dart';
import 'package:naazza/features/auth/domain/auth_user.dart';

void main() {
  test('birthday boundaries and past record ages use calendar dates', () {
    final user = AuthUser(
      id: '1',
      username: 'tester',
      birthDate: DateTime(2000, 10, 20),
    );
    expect(user.ageAt(DateTime(2026, 10, 19)), 25);
    expect(user.ageAt(DateTime(2026, 10, 20)), 26);
    expect(user.ageAt(DateTime(2025, 10, 20)), 25);
    expect(ageOn(DateTime(2000, 2, 29), DateTime(2025, 2, 28)), 24);
    expect(ageOn(DateTime(2000, 2, 29), DateTime(2025, 3, 1)), 25);
    expect(const AuthUser(id: '2', username: 'old').age, isNull);
  });
  test('missing, impossible and future dates stay unknown', () {
    final now = DateTime(2026, 10, 20);
    for (final date in [
      null,
      '',
      '2001-02-29',
      '2026-13-01',
      '2026-10-21',
      '2000-1-01',
      '1899-12-31',
    ]) {
      expect(parseBirthDate(date, today: now), isNull);
    }
    expect(
      birthDateText(parseBirthDate('2000-02-29', today: now)!),
      '2000-02-29',
    );
  });
}
