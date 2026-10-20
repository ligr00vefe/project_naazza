/// Calendar date only: never convert a birth date through UTC.
String birthDateText(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime? parseBirthDate(Object? value, {DateTime? today}) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final date = DateTime.tryParse(value);
  if (date == null || birthDateText(date) != value || date.year < 1900) {
    return null;
  }
  final now = today ?? DateTime.now();
  return date.isAfter(DateTime(now.year, now.month, now.day)) ? null : date;
}

int ageOn(DateTime birthDate, DateTime date) {
  final birthdayPending =
      date.month < birthDate.month ||
      (date.month == birthDate.month && date.day < birthDate.day);
  return date.year - birthDate.year - (birthdayPending ? 1 : 0);
}
