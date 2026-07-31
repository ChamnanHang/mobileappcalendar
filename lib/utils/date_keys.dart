/// Small helpers for keying and comparing calendar days.
library;

/// `YYYY-MM-DD`, used as a map key for a single day.
String dateKey(DateTime date) {
  final String m = date.month.toString().padLeft(2, '0');
  final String d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

/// Strips the time component so dates compare by day.
DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// The same day as a UTC instant — the lunar algorithm works in UTC.
DateTime dayOnlyUtc(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
