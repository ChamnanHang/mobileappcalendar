import 'package:flutter_test/flutter_test.dart';
import 'package:noted/data/khmer_holidays.dart';

/// The expected dates below were cross-checked against published Cambodian
/// holiday dates before the lunar rules were encoded.
void main() {
  List<String> namesOn(DateTime date) =>
      holidaysOn(date).map((KhmerHoliday h) => h.english).toList();

  bool hasHoliday(DateTime date, String english) =>
      namesOn(date).contains(english);

  group('Pchum Ben', () {
    test('main day falls on the published date each year', () {
      const Map<int, List<int>> expected = <int, List<int>>{
        2023: <int>[10, 14],
        2024: <int>[10, 2],
        2025: <int>[9, 22],
        2026: <int>[10, 11],
        2027: <int>[9, 30],
      };

      expected.forEach((int year, List<int> md) {
        final DateTime day = DateTime(year, md[0], md[1]);
        expect(isPchumBenDay(day), isTrue, reason: 'Pchum Ben $year');
        expect(hasHoliday(day, 'Pchum Ben'), isTrue, reason: 'Pchum Ben $year');
      });
    });

    test('public holiday is three days centred on the main day', () {
      // Sub-Decree No. 167 lists 10–12 October 2026, main day 11 October.
      for (final int day in <int>[10, 11, 12]) {
        expect(
          hasHoliday(DateTime(2026, 10, day), 'Pchum Ben'),
          isTrue,
          reason: '2026-10-$day',
        );
      }
      expect(hasHoliday(DateTime(2026, 10, 9), 'Pchum Ben'), isFalse);
      expect(hasHoliday(DateTime(2026, 10, 13), 'Pchum Ben'), isFalse);

      // 2025 was officially 21–23 September, main day 22 September.
      for (final int day in <int>[21, 22, 23]) {
        expect(
          hasHoliday(DateTime(2025, 9, day), 'Pchum Ben'),
          isTrue,
          reason: '2025-09-$day',
        );
      }
    });

    test('only one Pchum Ben main day per year', () {
      int count = 0;
      DateTime day = DateTime(2025, 1, 1);
      while (day.year == 2025) {
        if (isPchumBenDay(day)) count++;
        day = day.add(const Duration(days: 1));
      }
      expect(count, 1);
    });
  });

  group('other lunar festivals', () {
    test('Meak Bochea', () {
      expect(hasHoliday(DateTime(2024, 2, 24), 'Meak Bochea'), isTrue);
      expect(hasHoliday(DateTime(2025, 2, 12), 'Meak Bochea'), isTrue);
      expect(hasHoliday(DateTime(2026, 2, 2), 'Meak Bochea'), isTrue);
    });

    test('Visakha Bochea', () {
      expect(hasHoliday(DateTime(2024, 5, 22), 'Visakha Bochea'), isTrue);
      expect(hasHoliday(DateTime(2025, 5, 11), 'Visakha Bochea'), isTrue);
      expect(hasHoliday(DateTime(2026, 5, 1), 'Visakha Bochea'), isTrue);
    });

    test('Royal Ploughing Ceremony', () {
      expect(
        hasHoliday(DateTime(2025, 5, 15), 'Royal Ploughing Ceremony'),
        isTrue,
      );
      expect(
        hasHoliday(DateTime(2026, 5, 5), 'Royal Ploughing Ceremony'),
        isTrue,
      );
    });

    test('Chol Vossa, including a leap-month year', () {
      expect(hasHoliday(DateTime(2024, 7, 21), 'Chol Vossa'), isTrue);
      expect(hasHoliday(DateTime(2025, 7, 11), 'Chol Vossa'), isTrue);
      // 2026 is an adhikamas year, so it lands in the second Ashadha.
      expect(hasHoliday(DateTime(2026, 7, 30), 'Chol Vossa'), isTrue);
    });

    test('Chenh Vossa', () {
      expect(hasHoliday(DateTime(2024, 10, 17), 'Chenh Vossa'), isTrue);
      expect(hasHoliday(DateTime(2025, 10, 7), 'Chenh Vossa'), isTrue);
    });

    test('Water Festival spans three days', () {
      for (final int day in <int>[14, 15, 16]) {
        expect(
          hasHoliday(DateTime(2024, 11, day), 'Water Festival'),
          isTrue,
          reason: '2024-11-$day',
        );
      }
      expect(hasHoliday(DateTime(2024, 11, 17), 'Water Festival'), isFalse);

      for (final int day in <int>[4, 5, 6]) {
        expect(
          hasHoliday(DateTime(2025, 11, day), 'Water Festival'),
          isTrue,
          reason: '2025-11-$day',
        );
      }
    });
  });

  group('fixed and solar holidays', () {
    test('fixed-date holidays resolve', () {
      expect(hasHoliday(DateTime(2026, 1, 1), 'International New Year'), isTrue);
      expect(
        hasHoliday(DateTime(2026, 1, 7), 'Victory over Genocide Day'),
        isTrue,
      );
      expect(hasHoliday(DateTime(2026, 11, 9), 'Independence Day'), isTrue);
      expect(hasHoliday(DateTime(2026, 3, 8), "International Women's Day"),
          isTrue);
    });

    test('Khmer New Year comes from the solar computation', () {
      // 2025-04-14 04:48 is the widely published moment and both the local
      // reference and the deployed API agree on it.
      expect(hasHoliday(DateTime(2025, 4, 14), 'Khmer New Year'), isTrue);

      // 2026 is a leap-month year. The deployed API still answers 13 April
      // because it predates the local repo's commit "fix Khmer New Year
      // calculation for years where lunar epoch crosses month boundary";
      // this port follows the fixed source.
      for (final int day in <int>[14, 15, 16]) {
        expect(
          hasHoliday(DateTime(2026, 4, day), 'Khmer New Year'),
          isTrue,
          reason: '2026-04-$day',
        );
      }
      expect(hasHoliday(DateTime(2026, 4, 13), 'Khmer New Year'), isFalse);
      expect(hasHoliday(DateTime(2026, 4, 17), 'Khmer New Year'), isFalse);
    });

    test('an ordinary day has no holidays', () {
      expect(holidaysOn(DateTime(2026, 2, 17)), isEmpty);
    });

    test('matches Sub-Decree No. 167 for the whole of 2026', () {
      // Every public holiday in Cambodia's official 2026 schedule.
      const List<List<int>> official = <List<int>>[
        <int>[1, 1], <int>[1, 7], <int>[3, 8],
        <int>[4, 14], <int>[4, 15], <int>[4, 16], // Khmer New Year
        <int>[5, 1], // Labour Day + Visakha Bochea
        <int>[5, 5], // Royal Ploughing
        <int>[5, 14], <int>[6, 18], <int>[9, 24],
        <int>[10, 10], <int>[10, 11], <int>[10, 12], // Pchum Ben
        <int>[10, 15], <int>[10, 29], <int>[11, 9],
        <int>[11, 23], <int>[11, 24], <int>[11, 25], // Water Festival
        <int>[12, 29], // Peace Day
      ];

      for (final List<int> md in official) {
        final DateTime day = DateTime(2026, md[0], md[1]);
        expect(
          holidaysOn(day).any((KhmerHoliday h) => h.isPublicHoliday),
          isTrue,
          reason: 'expected a public holiday on 2026-${md[0]}-${md[1]}',
        );
      }

      // And nothing else in 2026 claims to be a public holiday.
      final Set<String> officialKeys =
          official.map((List<int> md) => '${md[0]}-${md[1]}').toSet();
      DateTime day = DateTime(2026, 1, 1);
      while (day.year == 2026) {
        final bool isPublic =
            holidaysOn(day).any((KhmerHoliday h) => h.isPublicHoliday);
        if (isPublic) {
          expect(
            officialKeys.contains('${day.month}-${day.day}'),
            isTrue,
            reason: 'unexpected public holiday on $day: ${namesOn(day)}',
          );
        }
        day = day.add(const Duration(days: 1));
      }
    });

    test('Peace Day was added by the 2024 sub-decree', () {
      expect(hasHoliday(DateTime(2026, 12, 29), 'Peace Day'), isTrue);
    });

    test('Water Festival matches the official 2026 dates', () {
      for (final int day in <int>[23, 24, 25]) {
        expect(
          hasHoliday(DateTime(2026, 11, day), 'Water Festival'),
          isTrue,
          reason: '2026-11-$day',
        );
      }
    });

    test('religious days that are not public holidays are observances', () {
      for (final DateTime day in <DateTime>[
        DateTime(2026, 2, 2), // Meak Bochea
        DateTime(2026, 7, 30), // Chol Vossa
        DateTime(2026, 10, 26), // Chenh Vossa
      ]) {
        final List<KhmerHoliday> found = holidaysOn(day);
        expect(found, isNotEmpty, reason: '$day');
        expect(
          found.every((KhmerHoliday h) => !h.isPublicHoliday),
          isTrue,
          reason: '$day should not be a public holiday',
        );
      }
    });

    test('Kan Ben days are observances, not public holidays', () {
      final List<KhmerHoliday> kanBen =
          holidaysOn(DateTime(2025, 9, 22).subtract(const Duration(days: 5)));
      expect(kanBen, isNotEmpty);
      expect(kanBen.every((KhmerHoliday h) => !h.isPublicHoliday), isTrue);
    });
  });
}
