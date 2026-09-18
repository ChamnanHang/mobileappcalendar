/// Per-month calendar data, computed once and kept.
///
/// Drawing a month means 42 lunar conversions plus a holy-day and holiday
/// lookup for each cell. That is only a few milliseconds, which is why the
/// calendar has no loading state — but it was being redone on every month
/// change, so stepping back and forth through a year recomputed the same
/// months over and over. They are immutable once computed, so they cache.
library;

import 'package:flutter/foundation.dart';

import '../utils/date_keys.dart';
import 'khmer_holidays.dart';
import 'khmer_lunar.dart';

/// Everything the grid and the detail panel need for a single month.
@immutable
class KhmerMonth {
  const KhmerMonth({
    required this.month,
    required this.days,
    required this.lunar,
    required this.holyDays,
    required this.holidays,
    this.error,
  });

  /// The first of the month this describes.
  final DateTime month;

  /// The 42 cells of a six-week, Sunday-first grid.
  final List<DateTime> days;

  final Map<String, KhLunarDate> lunar;
  final Set<String> holyDays;
  final Map<String, List<KhmerHoliday>> holidays;

  /// Set when the lunar computation threw, so the UI can say so rather than
  /// render a blank grid.
  final String? error;

  bool get computed => error == null;

  List<KhmerHoliday> holidaysOnKey(String key) =>
      holidays[key] ?? const <KhmerHoliday>[];

  /// The 42 cells covering [month], Sunday first.
  static List<DateTime> gridDays(DateTime month) {
    final DateTime first = DateTime(month.year, month.month);
    // DateTime.weekday is 1 = Monday … 7 = Sunday; % 7 puts Sunday in column 0.
    final DateTime start = first.subtract(Duration(days: first.weekday % 7));
    return List<DateTime>.generate(
      42,
      (int i) => DateTime(start.year, start.month, start.day + i),
      growable: false,
    );
  }

  /// Computes a month from scratch. Prefer [KhmerMonthCache.monthFor].
  factory KhmerMonth.compute(DateTime month) {
    final DateTime first = DateTime(month.year, month.month);
    final List<DateTime> days = gridDays(first);

    try {
      final Map<String, KhLunarDate> lunar = <String, KhLunarDate>{};
      final Set<String> holy = <String>{};
      final Map<String, List<KhmerHoliday>> holidays =
          <String, List<KhmerHoliday>>{};

      // One pass rather than two — the second loop used to re-walk the grid
      // just to collect holidays.
      for (final DateTime day in days) {
        final String key = dateKey(day);
        final DateTime utc = dayOnlyUtc(day);
        lunar[key] = findLunarDate(utc);
        if (isBuddhistHolyDay(utc)) holy.add(key);
        final List<KhmerHoliday> found = holidaysOn(day);
        if (found.isNotEmpty) holidays[key] = found;
      }

      return KhmerMonth(
        month: first,
        days: days,
        lunar: Map<String, KhLunarDate>.unmodifiable(lunar),
        holyDays: Set<String>.unmodifiable(holy),
        holidays: Map<String, List<KhmerHoliday>>.unmodifiable(holidays),
      );
    } on Object catch (error) {
      return KhmerMonth(
        month: first,
        days: days,
        lunar: const <String, KhLunarDate>{},
        holyDays: const <String>{},
        holidays: const <String, List<KhmerHoliday>>{},
        error: '$error',
      );
    }
  }
}

/// A small LRU of computed months.
///
/// [capacity] months is enough to step a year in either direction — the way
/// anyone actually browses a calendar — without recomputing.
class KhmerMonthCache {
  KhmerMonthCache({this.capacity = 14}) : assert(capacity > 0);

  final int capacity;

  // A LinkedHashMap preserves insertion order, so re-inserting on a hit is
  // enough to keep the eviction order correct.
  final Map<String, KhmerMonth> _cache = <String, KhmerMonth>{};

  int get length => _cache.length;

  KhmerMonth monthFor(DateTime month) {
    final String key =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';

    final KhmerMonth? hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }

    final KhmerMonth computed = KhmerMonth.compute(month);
    _cache[key] = computed;
    if (_cache.length > capacity) _cache.remove(_cache.keys.first);
    return computed;
  }

  /// Warms neighbouring months so a swipe lands on an already-computed grid.
  void precache(DateTime month) {
    monthFor(DateTime(month.year, month.month - 1));
    monthFor(DateTime(month.year, month.month + 1));
  }

  void clear() => _cache.clear();
}
