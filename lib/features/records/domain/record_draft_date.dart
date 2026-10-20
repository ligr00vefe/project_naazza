/// Preserve the selected local calendar date and a useful editable time.
DateTime calendarDraftTime(DateTime day, {DateTime? now}) {
  final time = now ?? DateTime.now();
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

String recordDateRoute(String path, DateTime? at) => at == null
    ? path
    : Uri(
        path: path,
        queryParameters: {'at': at.toLocal().toIso8601String()},
      ).toString();

DateTime? parseRecordDraftDate(String? raw, {DateTime? now}) {
  final at = DateTime.tryParse(raw ?? '')?.toLocal();
  if (at == null) return null;
  final today = now ?? DateTime.now();
  if (DateTime(
    at.year,
    at.month,
    at.day,
  ).isAfter(DateTime(today.year, today.month, today.day))) {
    return null;
  }
  return at;
}
