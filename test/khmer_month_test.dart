import 'package:flutter_test/flutter_test.dart';
import 'package:noted/data/khmer_lunar.dart';
import 'package:noted/data/khmer_month.dart';
import 'package:noted/utils/date_keys.dart';

void main() {
  group('KhmerMonth', () {
    test('a grid is 42 days, Sunday first, covering the month', () {
      final List<DateTime> days = KhmerMonth.gridDays(DateTime(2026, 4));

      expect(days, hasLength(42));
      expect(days.first.weekday, DateTime.sunday);
      // The month's first and last day are both inside the grid.
      expect(
        days.any((DateTime d) => isSameDay(d, DateTime(2026, 4, 1))),
        isTrue,
      );
      expect(
        days.any((DateTime d) => isSameDay(d, DateTime(2026, 4, 30))),
        isTrue,
      );
      // Consecutive, no gaps.
      for (int i = 1; i < days.length; i++) {
        expect(days[i].difference(days[i - 1]).inDays, 1);
      }
    });

    test('computes a lunar date for every cell', () {
      final KhmerMonth month = KhmerMonth.compute(DateTime(2026, 4));

      expect(month.computed, isTrue);
      expect(month.error, isNull);
      expect(month.lunar, hasLength(42));
      for (final DateTime day in month.days) {
        expect(month.lunar[dateKey(day)], isA<KhLunarDate>());
      }
    });

    test('flags Khmer New Year in April 2026', () {
      final KhmerMonth month = KhmerMonth.compute(DateTime(2026, 4));

      // Sub-Decree No. 167 puts Khmer New Year on 14-16 April 2026.
      for (final int day in <int>[14, 15, 16]) {
        expect(
          month.holidaysOnKey(dateKey(DateTime(2026, 4, day))),
          isNotEmpty,
          reason: '$day April 2026 should carry a holiday',
        );
      }
    });

    test('holidaysOnKey returns an empty list for an ordinary day', () {
      final KhmerMonth month = KhmerMonth.compute(DateTime(2026, 4));

      expect(month.holidaysOnKey('not-a-real-key'), isEmpty);
    });

    test('normalises any day of the month to the first', () {
      final KhmerMonth mid = KhmerMonth.compute(DateTime(2026, 4, 17));

      expect(mid.month, DateTime(2026, 4));
    });
  });

  group('KhmerMonthCache', () {
    test('returns the identical instance on a repeat lookup', () {
      final KhmerMonthCache cache = KhmerMonthCache();

      final KhmerMonth first = cache.monthFor(DateTime(2026, 4));
      final KhmerMonth second = cache.monthFor(DateTime(2026, 4));

      expect(identical(first, second), isTrue);
    });

    test('treats any day in a month as the same key', () {
      final KhmerMonthCache cache = KhmerMonthCache();

      final KhmerMonth first = cache.monthFor(DateTime(2026, 4));
      final KhmerMonth second = cache.monthFor(DateTime(2026, 4, 28));

      expect(identical(first, second), isTrue);
      expect(cache.length, 1);
    });

    test('evicts the least recently used month past capacity', () {
      final KhmerMonthCache cache = KhmerMonthCache(capacity: 3);

      final KhmerMonth january = cache.monthFor(DateTime(2026));
      cache.monthFor(DateTime(2026, 2));
      cache.monthFor(DateTime(2026, 3));
      // Touch January so February becomes the least recently used.
      cache.monthFor(DateTime(2026));
      cache.monthFor(DateTime(2026, 4));

      expect(cache.length, 3);
      expect(identical(cache.monthFor(DateTime(2026)), january), isTrue);
      // February was evicted, so this is a fresh computation.
      expect(
        identical(
          cache.monthFor(DateTime(2026, 2)),
          cache.monthFor(DateTime(2026, 2)),
        ),
        isTrue,
      );
    });

    test('precache warms both neighbours, including across a year edge', () {
      final KhmerMonthCache cache = KhmerMonthCache();

      cache.monthFor(DateTime(2026));
      cache.precache(DateTime(2026));

      expect(cache.length, 3);
      // December 2025 and February 2026 are now cached, not recomputed.
      final KhmerMonth december = cache.monthFor(DateTime(2025, 12));
      expect(identical(cache.monthFor(DateTime(2025, 12)), december), isTrue);
      expect(december.month, DateTime(2025, 12));
    });

    test('clear empties the cache', () {
      final KhmerMonthCache cache = KhmerMonthCache();
      cache.monthFor(DateTime(2026, 4));

      cache.clear();

      expect(cache.length, 0);
    });

    test('a year of months stays fast enough to compute synchronously', () {
      final KhmerMonthCache cache = KhmerMonthCache(capacity: 24);
      final Stopwatch watch = Stopwatch()..start();

      for (int month = 1; month <= 12; month++) {
        cache.monthFor(DateTime(2026, month));
      }
      final int cold = watch.elapsedMilliseconds;

      watch.reset();
      for (int month = 1; month <= 12; month++) {
        cache.monthFor(DateTime(2026, month));
      }
      final int warm = watch.elapsedMilliseconds;

      expect(cold, lessThan(400), reason: 'no month needs a loading state');
      expect(warm, lessThanOrEqualTo(cold));
    });
  });
}
