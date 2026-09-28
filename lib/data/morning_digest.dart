/// The text of the morning reminder: today's Khmer date, plus the holy days
/// and holidays falling today and tomorrow.
///
/// Pure Dart on top of the on-device calendar, so every future morning's text
/// can be worked out in advance and handed to the OS as a scheduled
/// notification — no background execution, no network.
library;

import 'package:flutter/foundation.dart';

import '../utils/date_keys.dart';
import '../utils/khmer_text.dart';
import 'khmer_holidays.dart';
import 'khmer_lunar.dart';

@immutable
class MorningDigest {
  const MorningDigest({required this.title, required this.body});

  /// Today's weekday and lunar date, e.g. `ថ្ងៃច័ន្ទ ២រោច ខែភទ្របទ`.
  final String title;

  /// One line for today and one for tomorrow, each only when something falls
  /// on that day; a single "nothing on" line otherwise.
  final String body;

  @override
  String toString() => '$title\n$body';
}

/// Shown when neither day has a holy day or holiday.
const String quietDaysLine = 'No holy day or holiday today or tomorrow.';

/// The reminder for the morning of [day].
MorningDigest buildMorningDigest(DateTime day) {
  final DateTime today = dayOnly(day);
  final DateTime tomorrow = DateTime(today.year, today.month, today.day + 1);

  final List<String> todayEvents = eventsOn(today);
  final List<String> tomorrowEvents = eventsOn(tomorrow);

  final List<String> lines = <String>[
    if (todayEvents.isNotEmpty) 'Today: ${todayEvents.join(', ')}',
    if (tomorrowEvents.isNotEmpty) 'Tomorrow: ${tomorrowEvents.join(', ')}',
  ];

  return MorningDigest(
    title: _titleFor(today),
    body: lines.isEmpty ? quietDaysLine : lines.join('\n'),
  );
}

/// Labels for everything falling on [day]: the holy day first, then holidays
/// and observances in calendar order. Empty for an ordinary day.
List<String> eventsOn(DateTime day) {
  final DateTime utc = dayOnlyUtc(day);
  final List<String> events = <String>[];
  try {
    if (isBuddhistHolyDay(utc)) events.add('ថ្ងៃសីល (holy day)');
    for (final KhmerHoliday holiday in holidaysOn(day)) {
      events.add('${holiday.khmer} (${holiday.english})');
    }
  } on Object catch (error) {
    // Same stance as the calendar grid: a day the lunar maths cannot place is
    // reported as having nothing on rather than taking the reminder down.
    debugPrint('Could not compute events for $day: $error');
  }
  return events;
}

String _titleFor(DateTime day) {
  final String weekday = 'ថ្ងៃ${weekdayName(day)}';
  try {
    final KhLunarDate lunar = findLunarDate(dayOnlyUtc(day));
    return '$weekday ${lunarDayToken(lunar.day)} ខែ${lunarMonthName(lunar.month)}';
  } on Object {
    return '$weekday ${day.day} ${gregorianMonthName(day.month)}';
  }
}
