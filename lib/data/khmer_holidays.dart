/// Khmer holidays and observances, derived from the lunar calendar rather than
/// stored as a per-year lookup table — so they are correct for any year.
///
/// Each lunar rule below was checked against published dates before being
/// encoded; see `test/khmer_holidays_test.dart`.
library;

import '../utils/date_keys.dart';
import 'khmer_lunar.dart';

enum HolidayKind {
  /// An official public holiday.
  publicHoliday,

  /// Observed, but not a day off (Kan Ben, for example).
  observance,
}

class KhmerHoliday {
  const KhmerHoliday(
    this.khmer,
    this.english, {
    this.kind = HolidayKind.publicHoliday,
  });

  final String khmer;
  final String english;
  final HolidayKind kind;

  bool get isPublicHoliday => kind == HolidayKind.publicHoliday;
}

/// Fixed-date holidays, keyed `MM-DD`.
///
/// Checked against Cambodia's Sub-Decree No. 167 of 18 September 2025, which
/// sets the 2026 schedule. The list is re-issued annually, so a specific year's
/// decree can differ — treat this as the standing set, not a legal reference.
const Map<String, KhmerHoliday> _fixedHolidays = <String, KhmerHoliday>{
  '01-01': KhmerHoliday('ចូលឆ្នាំសាកល', 'International New Year'),
  '01-07': KhmerHoliday('ទិវាជ័យជម្នះ ៧ មករា', 'Victory over Genocide Day'),
  '03-08': KhmerHoliday('ទិវានារីអន្តរជាតិ', "International Women's Day"),
  '05-01': KhmerHoliday('ទិវាពលកម្មអន្តរជាតិ', 'International Labour Day'),
  '05-14': KhmerHoliday(
    'ព្រះរាជពិធីបុណ្យចម្រើនព្រះជន្ម ព្រះមហាក្សត្រ',
    "King Sihamoni's Birthday",
  ),
  '06-18': KhmerHoliday(
    'ទិវាកំណើតសម្តេចម្តាយ',
    "King's Mother's Birthday",
  ),
  '09-24': KhmerHoliday('ទិវារដ្ឋធម្មនុញ្ញ', 'Constitution Day'),
  '10-15': KhmerHoliday(
    'ទិវាប្រារព្ធពិធីគោរពព្រះវិញ្ញាណក្ខន្ធ ព្រះបរមរតនកោដ្ឋ',
    'Commemoration of the King Father',
  ),
  '10-29': KhmerHoliday(
    'ព្រះរាជពិធីគ្រងព្រះបរមរាជសម្បត្តិ',
    "King's Coronation Day",
  ),
  '11-09': KhmerHoliday('ទិវាឯករាជ្យជាតិ', 'Independence Day'),
  '12-10': KhmerHoliday(
    'ទិវាសិទ្ធិមនុស្សអន្តរជាតិ',
    'International Human Rights Day',
    kind: HolidayKind.observance,
  ),
  // Established by sub-decree in 2024.
  '12-29': KhmerHoliday('ទិវាសន្តិភាព', 'Peace Day'),
};

/// Every holiday and observance falling on [date].
List<KhmerHoliday> holidaysOn(DateTime date) {
  final DateTime utc = dayOnlyUtc(date);
  final List<KhmerHoliday> found = <KhmerHoliday>[];

  final String key =
      '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  final KhmerHoliday? fixed = _fixedHolidays[key];
  if (fixed != null) found.add(fixed);

  // Khmer New Year — three or four days, computed from the solar reckoning.
  for (final DateTime day in khmerNewYearDays(date.year)) {
    if (isSameDay(day, date)) {
      found.add(const KhmerHoliday('បុណ្យចូលឆ្នាំថ្មី', 'Khmer New Year'));
      break;
    }
  }

  found.addAll(_lunarHolidaysOn(utc));
  return found;
}

/// Holidays fixed to a lunar month and day.
///
/// Day indices are 0-based: 0–14 is waxing (កើត) 1–15, and 15–29 is waning
/// (រោច) 1–15.
List<KhmerHoliday> _lunarHolidaysOn(DateTime utc) {
  final KhLunarDate lunar = findLunarDate(utc);
  final int month = lunar.month;
  final int day = lunar.day;
  final List<KhmerHoliday> found = <KhmerHoliday>[];

  // ១៥ កើត ខែមាឃ — dropped from the public-holiday list in 2020.
  if (month == KhMonth.meak && day == 14) {
    found.add(const KhmerHoliday(
      'ពិធីបុណ្យមាឃបូជា',
      'Meak Bochea',
      kind: HolidayKind.observance,
    ));
  }

  // ១៥ កើត ខែពិសាខ
  if (month == KhMonth.pisak && day == 14) {
    found.add(const KhmerHoliday('ពិធីបុណ្យវិសាខបូជា', 'Visakha Bochea'));
  }

  // ៤ រោច ខែពិសាខ
  if (month == KhMonth.pisak && day == 18) {
    found.add(const KhmerHoliday(
      'ព្រះរាជពិធីច្រត់ព្រះនង្គ័ល',
      'Royal Ploughing Ceremony',
    ));
  }

  // ១ រោច ខែអាសាឍ — the second Ashadha in a leap-month year.
  // Religious observances rather than public holidays.
  if ((month == KhMonth.asath || month == KhMonth.tutiyasath) && day == 15) {
    found.add(const KhmerHoliday(
      'ពិធីបុណ្យចូលវស្សា',
      'Chol Vossa',
      kind: HolidayKind.observance,
    ));
  }

  // ១៥ កើត ខែអស្សុជ
  if (month == KhMonth.assoch && day == 14) {
    found.add(const KhmerHoliday(
      'ពិធីបុណ្យចេញវស្សា',
      'Chenh Vossa',
      kind: HolidayKind.observance,
    ));
  }

  // ១៤ កើត – ១ រោច ខែកក្ដិក
  if (month == KhMonth.kadeuk && day >= 13 && day <= 15) {
    found.add(const KhmerHoliday('ពិធីបុណ្យអុំទូក', 'Water Festival'));
  }

  // Pchum Ben's public holiday is three days centred on the main day — the day
  // before, the day itself and the day after. Sub-Decree No. 167 lists
  // 10–12 October 2026 against a main day of 11 October.
  if (_isPchumBenMain(utc) ||
      _isPchumBenMain(utc.subtract(const Duration(days: 1))) ||
      _isPchumBenMain(utc.add(const Duration(days: 1)))) {
    found.add(const KhmerHoliday('ពិធីបុណ្យភ្ជុំបិណ្ឌ', 'Pchum Ben'));
  }

  // កាន់បិណ្ឌ runs 1 រោច–14 រោច of ភទ្របទ, ending the day before Pchum Ben.
  if (month == KhMonth.phatrabot && day >= 15 && day <= 28) {
    found.add(KhmerHoliday(
      'កាន់បិណ្ឌ ទី${day - 14}',
      'Kan Ben day ${day - 14}',
      kind: HolidayKind.observance,
    ));
  }

  return found;
}

bool _isPchumBenMain(DateTime utc) {
  final KhLunarDate lunar = findLunarDate(utc);
  return lunar.month == KhMonth.phatrabot && lunar.day == 29;
}

/// True when [date] is the main day of Pchum Ben (១៥ រោច ខែភទ្របទ).
bool isPchumBenDay(DateTime date) => _isPchumBenMain(dayOnlyUtc(date));
