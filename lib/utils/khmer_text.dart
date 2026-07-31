/// Khmer numerals, month/weekday names and lunar-day labels.
///
/// The lunar month table was verified against the API by comparing
/// `/lunar-date/` month indices with the Khmer names in
/// `/lunar-date/formatted/` across a full year.
library;

const List<String> _khmerDigits = <String>[
  '០',
  '១',
  '២',
  '៣',
  '៤',
  '៥',
  '៦',
  '៧',
  '៨',
  '៩',
];

/// Converts every ASCII digit in [input] to its Khmer numeral.
String toKhmerDigits(Object input) {
  final String text = input.toString();
  final StringBuffer out = StringBuffer();
  for (final int code in text.codeUnits) {
    if (code >= 0x30 && code <= 0x39) {
      out.write(_khmerDigits[code - 0x30]);
    } else {
      out.writeCharCode(code);
    }
  }
  return out.toString();
}

/// Lunar months, indexed by the API's `month` field (0–13).
///
/// 12 and 13 are the doubled Ashadha months used in an adhikamas (leap) year;
/// in such a year index 7 does not occur.
const List<String> khmerLunarMonths = <String>[
  'មិគសិរ', // 0
  'បុស្ស', // 1
  'មាឃ', // 2
  'ផល្គុន', // 3
  'ចេត្រ', // 4
  'ពិសាខ', // 5
  'ជេស្ឋ', // 6
  'អាសាឍ', // 7
  'ស្រាពណ៍', // 8
  'ភទ្របទ', // 9
  'អស្សុជ', // 10
  'កក្ដិក', // 11
  'បឋមាសាឍ', // 12
  'ទុតិយាសាឍ', // 13
];

String lunarMonthName(int index) =>
    index >= 0 && index < khmerLunarMonths.length
    ? khmerLunarMonths[index]
    : '—';

/// Gregorian months in Khmer, indexed 1–12.
const List<String> khmerGregorianMonths = <String>[
  '',
  'មករា',
  'កុម្ភៈ',
  'មីនា',
  'មេសា',
  'ឧសភា',
  'មិថុនា',
  'កក្កដា',
  'សីហា',
  'កញ្ញា',
  'តុលា',
  'វិច្ឆិកា',
  'ធ្នូ',
];

String gregorianMonthName(int month) =>
    month >= 1 && month <= 12 ? khmerGregorianMonths[month] : '—';

/// Weekday names in the source locale's order, Sunday first.
const List<String> khmerWeekdays = <String>[
  'អាទិត្យ',
  'ច័ន្ទ',
  'អង្គារ',
  'ពុធ',
  'ព្រហស្បតិ៍',
  'សុក្រ',
  'សៅរ៍',
];

/// [DateTime.weekday] is 1 = Monday … 7 = Sunday; `% 7` maps Sunday to 0.
int sundayFirstIndex(DateTime date) => date.weekday % 7;

String weekdayName(DateTime date) => khmerWeekdays[sundayFirstIndex(date)];

/// The twelve-year animal cycle. `មមីរ` is the source locale's spelling.
const List<String> khmerAnimalYears = <String>[
  'ជូត',
  'ឆ្លូវ',
  'ខាល',
  'ថោះ',
  'រោង',
  'ម្សាញ់',
  'មមីរ',
  'មមែ',
  'វក',
  'រកា',
  'ច',
  'កុរ',
];

/// The ten-year era cycle (ស័ក).
const List<String> khmerEraYears = <String>[
  'សំរឹទ្ធិស័ក',
  'ឯកស័ក',
  'ទោស័ក',
  'ត្រីស័ក',
  'ចត្វាស័ក',
  'បញ្ចស័ក',
  'ឆស័ក',
  'សប្តស័ក',
  'អដ្ឋស័ក',
  'នព្វស័ក',
];

/// Column headers for a Sunday-first grid.
const List<String> weekdayInitials = <String>[
  'អា',
  'ច',
  'អ',
  'ព',
  'ព្រ',
  'សុ',
  'ស',
];

/// Half of the lunar month a day falls in.
enum MoonHalf {
  /// កើត — the waxing fortnight.
  waxing,

  /// រោច — the waning fortnight.
  waning,
}

/// A lunar day index (0–29) split into its fortnight and 1-based number.
///
/// Index 0–14 is waxing 1–15; 15–29 is waning 1–15. Verified against the API:
/// index 15 formats as `១រោច`.
class LunarDay {
  const LunarDay(this.index);

  final int index;

  MoonHalf get half => index < 15 ? MoonHalf.waxing : MoonHalf.waning;

  int get number => index < 15 ? index + 1 : index - 14;

  String get halfLabel => half == MoonHalf.waxing ? 'កើត' : 'រោច';

  /// e.g. `១រោច`
  String get label => '${toKhmerDigits(number)}$halfLabel';

  /// Full moon closes the waxing fortnight; the dark moon closes the month.
  bool get isFullMoon => index == 14;

  bool get isNewMoon => index == 29 || index == 28;

  /// A coarse phase glyph for the day cell.
  String get glyph {
    if (isFullMoon) return '●';
    if (index == 29) return '○';
    return half == MoonHalf.waxing ? '◐' : '◑';
  }
}
