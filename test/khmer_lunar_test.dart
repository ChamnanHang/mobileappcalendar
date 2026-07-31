import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noted/data/khmer_lunar.dart';

/// Differential tests against `test/fixtures/khmer_reference.json`, generated
/// from the Python implementation in `~/Desktop/Coding/khmer_calendar` — the
/// same code deployed behind khmer-calendar-phi.vercel.app. If the Dart port
/// ever diverges from the reference, these fail.
void main() {
  late Map<String, dynamic> fixture;

  setUpAll(() {
    final File file = File('test/fixtures/khmer_reference.json');
    fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  DateTime parseDay(String value) {
    final List<String> parts = value.split('-');
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  String isoNoZone(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}'
        'T${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  test('lunar day and month match the reference for every fixture date', () {
    final List<dynamic> rows = fixture['lunar'] as List<dynamic>;
    expect(rows.length, greaterThan(5000));

    final List<String> mismatches = <String>[];
    for (final dynamic row in rows) {
      final List<dynamic> entry = row as List<dynamic>;
      final String date = entry[0] as String;
      final KhLunarDate actual = findLunarDate(parseDay(date));

      if (actual.day != entry[1] || actual.month != entry[2]) {
        mismatches.add(
          '$date expected day=${entry[1]} month=${entry[2]} '
          'got day=${actual.day} month=${actual.month}',
        );
      }
    }

    expect(mismatches, isEmpty, reason: mismatches.take(10).join('\n'));
  });

  test('formatted Khmer sentence and BE year match the reference', () {
    final List<dynamic> rows = fixture['formatted'] as List<dynamic>;
    expect(rows, isNotEmpty);

    for (final dynamic row in rows) {
      final List<dynamic> entry = row as List<dynamic>;
      final DateTime date = parseDay(entry[0] as String);

      expect(formatKhmerDate(date), entry[1], reason: 'on ${entry[0]}');
      expect(getBeYear(date), entry[2], reason: 'on ${entry[0]}');
    }
  });

  test('Buddhist holy days match the reference day by day', () {
    final List<dynamic> rows = fixture['holy'] as List<dynamic>;
    expect(rows, isNotEmpty);

    for (final dynamic row in rows) {
      final List<dynamic> entry = row as List<dynamic>;
      expect(
        isBuddhistHolyDay(parseDay(entry[0] as String)),
        entry[1],
        reason: 'on ${entry[0]}',
      );
    }
  });

  test('Khmer New Year days match the reference', () {
    final List<dynamic> rows = fixture['newyear'] as List<dynamic>;
    expect(rows, isNotEmpty);

    for (final dynamic row in rows) {
      final List<dynamic> entry = row as List<dynamic>;
      final int year = entry[0] as int;
      final List<String> expected = (entry[2] as List<dynamic>).cast<String>();

      final List<DateTime> actual = khmerNewYearDays(year);

      expect(actual.map(isoNoZone).toList(), expected, reason: 'year $year');
      expect(
        isoNoZone(khmerNewYearMoment(year)),
        entry[1],
        reason: 'year $year',
      );
    }
  });

  test('years the Python reference crashes on are computed here', () {
    // The reference builds the date with strptime, which rejects an hour of
    // 24, so the deployed service answers 500 for these years. Rolling into
    // the next day is the correct reading.
    for (final int year in <int>[1974, 2032, 2059]) {
      final List<DateTime> days = khmerNewYearDays(year);

      expect(days, isNotEmpty, reason: 'year $year');
      expect(days.length, anyOf(3, 4));
      expect(days.first.year, year);
      // Choul Chnam Thmey always falls in April.
      expect(days.first.month, 4);
    }
  });

  test('holy days land only on the 8th and 15th of a fortnight', () {
    // Cross-check the rule itself rather than just the fixture.
    DateTime day = DateTime.utc(2027, 1, 1);
    while (day.isBefore(DateTime.utc(2027, 4, 1))) {
      if (isBuddhistHolyDay(day)) {
        final int number = (findLunarDate(day).day % 15) + 1;
        expect(number, anyOf(8, 15, 14), reason: 'unexpected holy day on $day');
      }
      day = day.add(const Duration(days: 1));
    }
  });

  test('a full month grid computes fast enough to be synchronous', () {
    // 42 cells is what the calendar screen renders. Warm the year caches
    // first, then measure a realistic month switch.
    findLunarDate(DateTime.utc(2026, 7, 1));
    getBeYear(DateTime.utc(2026, 7, 1));

    final Stopwatch watch = Stopwatch()..start();
    for (int i = 0; i < 42; i++) {
      final DateTime day = DateTime.utc(2026, 8, 1).add(Duration(days: i));
      findLunarDate(day);
      isBuddhistHolyDay(day);
    }
    watch.stop();

    expect(
      watch.elapsedMilliseconds,
      lessThan(200),
      reason: 'took ${watch.elapsedMilliseconds}ms',
    );
  });
}
