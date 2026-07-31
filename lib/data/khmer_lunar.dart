/// Pure-Dart port of the Khmer lunar calendar algorithm (momentkh / Soriyatra
/// Lerng Sak), computed on-device instead of calling a web service.
///
/// Ported from the Python reference in `~/Desktop/Coding/khmer_calendar`
/// (`khmer_calendar.py` + `soriyatra_lerng_sak.py`), which is the same code
/// deployed behind khmer-calendar-phi.vercel.app. `test/khmer_lunar_test.dart`
/// checks this port against a fixture generated from that reference.
///
/// All arithmetic uses **UTC** `DateTime`s: the reference uses naive Python
/// datetimes, and local-time arithmetic would drift across DST boundaries.
library;

import '../utils/khmer_text.dart';

// ---------------------------------------------------------------- lunar months

/// Indices into [khmerLunarMonths].
class KhMonth {
  KhMonth._();

  static const int migasir = 0;
  static const int bos = 1;
  static const int meak = 2;
  static const int phalkun = 3;
  static const int chetr = 4;
  static const int pisak = 5;
  static const int jesth = 6;
  static const int asath = 7;
  static const int srapoan = 8;
  static const int phatrabot = 9;
  static const int assoch = 10;
  static const int kadeuk = 11;
  static const int bathomasath = 12;
  static const int tutiyasath = 13;
}

/// The result of a Gregorian → lunar conversion.
class KhLunarDate {
  const KhLunarDate({
    required this.day,
    required this.month,
    required this.epochMoved,
  });

  /// Lunar day index, 0–29 (0–14 waxing កើត, 15–29 waning រោច).
  final int day;

  /// Lunar month index, 0–13 — see [KhMonth].
  final int month;

  final DateTime epochMoved;
}

// ---------------------------------------------------------------- small maths

/// Floor division matching Python's `//` for negative operands.
int _floorDiv(int a, int b) {
  final int q = a ~/ b;
  return (a % b != 0 && ((a < 0) != (b < 0))) ? q - 1 : q;
}

DateTime _utc(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    DateTime.utc(year, month, day, hour, minute);

DateTime _addDays(DateTime from, int days) => from.add(Duration(days: days));

/// Fractional days between two instants, mirroring the reference's
/// `(b - a).total_seconds() / 86400`.
double _daysBetween(DateTime a, DateTime b) =>
    b.difference(a).inMicroseconds / Duration.microsecondsPerDay;

// ------------------------------------------------------- BE-based core values

int getAharkun(int beYear) => _floorDiv(beYear * 292207 + 499, 800) + 4;

int getAharkunMod(int beYear) => (beYear * 292207 + 499) % 800;

int getAvoman(int beYear) => (11 * getAharkun(beYear) + 25) % 692;

int getBodithey(int beYear) {
  final int aharkun = getAharkun(beYear);
  final int avoman = _floorDiv(11 * aharkun + 25, 692);
  return (avoman + aharkun + 29) % 30;
}

int kromthupul(int beYear) => 800 - getAharkunMod(beYear);

bool isKhmerSolarLeap(int beYear) => kromthupul(beYear) <= 207;

/// 0 regular, 1 leap month, 2 leap day, 3 both.
int getBoditheyLeap(int beYear) {
  final int avoman = getAvoman(beYear);
  final int bodithey = getBodithey(beYear);

  int boditheyLeap = (bodithey >= 25 || bodithey <= 5) ? 1 : 0;

  int avomanLeap = 0;
  if (isKhmerSolarLeap(beYear)) {
    if (avoman <= 126) avomanLeap = 1;
  } else if (avoman <= 137) {
    avomanLeap = getAvoman(beYear + 1) == 0 ? 0 : 1;
  }

  // Consecutive 25/5 is not a leap month; 24 followed by 6 is.
  if (bodithey == 25 && getBodithey(beYear + 1) == 5) boditheyLeap = 0;
  if (bodithey == 24 && getBodithey(beYear + 1) == 6) boditheyLeap = 1;

  if (boditheyLeap == 1 && avomanLeap == 1) return 3;
  if (boditheyLeap == 1) return 1;
  if (avomanLeap == 1) return 2;
  return 0;
}

/// Normalised so a leap month and a leap day never land in the same year.
int getProtetinLeap(int beYear) {
  final int b = getBoditheyLeap(beYear);
  if (b == 3) return 1;
  if (b == 2 || b == 1) return b;
  if (getBoditheyLeap(beYear - 1) == 3) return 2;
  return 0;
}

bool isKhmerLeapMonth(int beYear) => getProtetinLeap(beYear) == 1;

bool isKhmerLeapDay(int beYear) => getProtetinLeap(beYear) == 2;

// --------------------------------------------------------------- day counting

int getNumberOfDayInKhmerMonth(int beMonth, int beYear) {
  if (beMonth == KhMonth.jesth && isKhmerLeapDay(beYear)) return 30;
  if (beMonth == KhMonth.bathomasath || beMonth == KhMonth.tutiyasath) {
    return 30;
  }
  return beMonth % 2 == 0 ? 29 : 30;
}

int getNumberOfDayInKhmerYear(int beYear) {
  if (isKhmerLeapMonth(beYear)) return 384;
  if (isKhmerLeapDay(beYear)) return 355;
  return 354;
}

/// Rough BE year used for intermediate stepping: April or earlier counts as the
/// previous BE year.
int _maybeBeYearOf(int year, int month) => month <= 4 ? year + 543 : year + 544;

int getMaybeBeYear(DateTime date) => _maybeBeYearOf(date.year, date.month);

int nextMonthOf(int khmerMonth, int beYear) {
  switch (khmerMonth) {
    case KhMonth.migasir:
      return KhMonth.bos;
    case KhMonth.bos:
      return KhMonth.meak;
    case KhMonth.meak:
      return KhMonth.phalkun;
    case KhMonth.phalkun:
      return KhMonth.chetr;
    case KhMonth.chetr:
      return KhMonth.pisak;
    case KhMonth.pisak:
      return KhMonth.jesth;
    case KhMonth.jesth:
      return isKhmerLeapMonth(beYear) ? KhMonth.bathomasath : KhMonth.asath;
    case KhMonth.asath:
      return KhMonth.srapoan;
    case KhMonth.srapoan:
      return KhMonth.phatrabot;
    case KhMonth.phatrabot:
      return KhMonth.assoch;
    case KhMonth.assoch:
      return KhMonth.kadeuk;
    case KhMonth.kadeuk:
      return KhMonth.migasir;
    case KhMonth.bathomasath:
      return KhMonth.tutiyasath;
    case KhMonth.tutiyasath:
      return KhMonth.srapoan;
    default:
      throw ArgumentError('Invalid lunar month index: $khmerMonth');
  }
}

// ------------------------------------------------------------ core conversion

final Map<String, KhLunarDate> _lunarCache = <String, KhLunarDate>{};

/// Converts a Gregorian date to its Khmer lunar day and month.
///
/// Walks forward (or back) from the 1 Jan 1900 epoch a Khmer year at a time,
/// then a Khmer month at a time.
KhLunarDate findLunarDate(DateTime target) {
  final DateTime utcTarget = target.isUtc
      ? target
      : _utc(target.year, target.month, target.day, target.hour, target.minute);

  final String key = utcTarget.toIso8601String();
  final KhLunarDate? cached = _lunarCache[key];
  if (cached != null) return cached;

  DateTime epoch = _utc(1900, 1, 1);
  int khmerMonth = KhMonth.bos;
  int khmerDay = 0;

  if (!utcTarget.isBefore(epoch)) {
    while (true) {
      final int daysNextYear = getNumberOfDayInKhmerYear(
        _maybeBeYearOf(epoch.year + 1, epoch.month),
      );
      if (_daysBetween(epoch, utcTarget) > daysNextYear) {
        epoch = _addDays(epoch, daysNextYear);
      } else {
        break;
      }
    }
  } else {
    while (true) {
      epoch = _addDays(
        epoch,
        -getNumberOfDayInKhmerYear(getMaybeBeYear(epoch)),
      );
      if (_daysBetween(epoch, utcTarget) >= 0) break;
    }
  }

  while (_daysBetween(epoch, utcTarget) >
      getNumberOfDayInKhmerMonth(khmerMonth, getMaybeBeYear(epoch))) {
    epoch = _addDays(
      epoch,
      getNumberOfDayInKhmerMonth(khmerMonth, getMaybeBeYear(epoch)),
    );
    khmerMonth = nextMonthOf(khmerMonth, getMaybeBeYear(epoch));
  }

  khmerDay += _daysBetween(epoch, utcTarget).truncate();

  final int totalDaysOfMonth = getNumberOfDayInKhmerMonth(
    khmerMonth,
    getMaybeBeYear(utcTarget),
  );
  if (totalDaysOfMonth <= khmerDay) {
    khmerDay = khmerDay % totalDaysOfMonth;
    khmerMonth = nextMonthOf(khmerMonth, getMaybeBeYear(epoch));
  }

  epoch = _addDays(epoch, _daysBetween(epoch, utcTarget).truncate());

  final KhLunarDate result = KhLunarDate(
    day: khmerDay,
    month: khmerMonth,
    epochMoved: epoch,
  );
  if (_lunarCache.length > 4000) _lunarCache.clear();
  _lunarCache[key] = result;
  return result;
}

// ------------------------------------------------------------------- BE years

final Map<int, DateTime> _visakhaBocheaCache = <int, DateTime>{};

/// Visakha Bochea: the day whose lunar date is the 15th waxing of ពិសាខ.
///
/// Scanning a year costs up to 366 conversions, so results are memoised —
/// this is the single most expensive call in the algorithm.
DateTime getVisakhaBochea(int gregorianYear) {
  final DateTime? cached = _visakhaBocheaCache[gregorianYear];
  if (cached != null) return cached;

  final DateTime start = _utc(gregorianYear, 1, 1);
  for (int i = 0; i < 366; i++) {
    final DateTime day = _addDays(start, i);
    final KhLunarDate lunar = findLunarDate(day);
    if (lunar.month == KhMonth.pisak && lunar.day == 14) {
      _visakhaBocheaCache[gregorianYear] = day;
      return day;
    }
  }
  throw StateError('Cannot find Visakha Bochea for $gregorianYear.');
}

/// Buddhist Era year: rolls over the day after Visakha Bochea.
int getBeYear(DateTime date) {
  final DateTime utcDate = date.isUtc
      ? date
      : _utc(date.year, date.month, date.day, date.hour, date.minute);
  return utcDate.isAfter(getVisakhaBochea(utcDate.year))
      ? utcDate.year + 544
      : utcDate.year + 543;
}

// ------------------------------------------------- Soriyatra Lerng Sak (solar)

class _SoriyatraInfo {
  const _SoriyatraInfo({
    required this.harkun,
    required this.kromathopol,
    required this.avaman,
    required this.bodithey,
  });

  final int harkun;
  final int kromathopol;
  final int avaman;
  final int bodithey;
}

_SoriyatraInfo _soriyatraInfo(int year) {
  final int h = 292207 * year + 373;
  final int harkun = _floorDiv(h, 800) + 1;
  final int kromathopol = 800 - (h % 800);
  final int a = 11 * harkun + 650;
  return _SoriyatraInfo(
    harkun: harkun,
    kromathopol: kromathopol,
    avaman: a % 692,
    bodithey: (harkun + _floorDiv(a, 692)) % 30,
  );
}

bool _has366Day(int year) => _soriyatraInfo(year).kromathopol <= 207;

bool _isAthikameas(int year) {
  final _SoriyatraInfo y = _soriyatraInfo(year);
  final _SoriyatraInfo next = _soriyatraInfo(year + 1);
  return !(y.bodithey == 25 && next.bodithey == 5) &&
      (y.bodithey > 24 ||
          y.bodithey < 6 ||
          (y.bodithey == 24 && next.bodithey == 6));
}

/// Result of the solar new-year computation for a Jolak Sakaraj year.
class SoriyatraLerngSak {
  const SoriyatraLerngSak({
    required this.newYearDayAngsarIsZero,
    required this.lunarDateLerngSakDay,
    required this.lunarDateLerngSakMonth,
    required this.hour,
    required this.minute,
  });

  /// True when the first candidate sotin already sits at angsar 0, which makes
  /// the New Year four days long instead of three.
  final bool newYearDayAngsarIsZero;

  final int lunarDateLerngSakDay;
  final int lunarDateLerngSakMonth;

  /// Hour may be 24, meaning midnight at the end of 17 April.
  final int hour;
  final int minute;
}

SoriyatraLerngSak getSoriyatraLerngSak(int jsYear) {
  final _SoriyatraInfo info = _soriyatraInfo(jsYear);

  // Lunar date of Lerng Sak.
  int bodithey = info.bodithey;
  if (_isAthikameas(jsYear - 1) && _isChantreathimeas(jsYear - 1)) {
    bodithey = (bodithey + 1) % 30;
  }
  final int ldsDay = bodithey >= 6 ? bodithey - 1 : bodithey;
  final int ldsMonth = bodithey >= 6 ? KhMonth.chetr : KhMonth.pisak;

  final List<int> sotins = _has366Day(jsYear - 1)
      ? <int>[363, 364, 365, 366]
      : <int>[362, 363, 364, 365];

  int? newYearLibda;
  bool firstAngsarIsZero = false;
  bool found = false;

  for (int i = 0; i < sotins.length; i++) {
    final int libdaTotal = _sunInaugurationAsLibda(jsYear, sotins[i]);
    final int angsar = _floorDiv(libdaTotal % (30 * 60), 60);
    if (i == 0 && angsar == 0) firstAngsarIsZero = true;
    if (!found && angsar == 0) {
      newYearLibda = libdaTotal % 60;
      found = true;
    }
  }

  if (!found) {
    throw StateError('No sotin with angsar 0 for Jolak Sakaraj year $jsYear.');
  }

  final int minutes = (24 * 60) - (newYearLibda! * 24);
  return SoriyatraLerngSak(
    newYearDayAngsarIsZero: firstAngsarIsZero,
    lunarDateLerngSakDay: ldsDay,
    lunarDateLerngSakMonth: ldsMonth,
    hour: _floorDiv(minutes, 60),
    minute: minutes % 60,
  );
}

bool _isChantreathimeas(int year) {
  final _SoriyatraInfo y = _soriyatraInfo(year);
  final _SoriyatraInfo next = _soriyatraInfo(year + 1);
  final _SoriyatraInfo prev = _soriyatraInfo(year - 1);
  final bool has366 = _has366Day(year);
  return (has366 && y.avaman < 127) ||
      !(y.avaman == 137 && next.avaman == 0) &&
          ((!has366 && y.avaman < 138) ||
              (prev.avaman == 137 && y.avaman == 0));
}

/// The sun's inaugurated position for a given sotin, in libda.
int _sunInaugurationAsLibda(int jsYear, int sotin) {
  final _SoriyatraInfo prev = _soriyatraInfo(jsYear - 1);

  final int r2 = 800 * sotin + prev.kromathopol;
  final int reasey = _floorDiv(r2, 24350);
  final int angsar = _floorDiv(r2 % 24350, 811);
  final int libda = _floorDiv((r2 % 24350) % 811, 14) - 3;

  final int sunAverage = (30 * 60 * reasey) + (60 * angsar) + libda;

  final int s1 = (30 * 60 * 2) + (60 * 20);
  int leftOver = sunAverage - s1;
  if (sunAverage < s1) leftOver += 30 * 60 * 12;

  final int kaen = _floorDiv(leftOver, 30 * 60);

  final int rs;
  if (kaen <= 2) {
    rs = kaen;
  } else if (kaen <= 5) {
    rs = (30 * 60 * 6) - leftOver;
  } else if (kaen <= 8) {
    rs = leftOver - (30 * 60 * 6);
  } else if (kaen <= 11) {
    rs = ((30 * 60 * 11) + (60 * 29) + 60) - leftOver;
  } else {
    rs = 0;
  }

  final int reaseyRs = _floorDiv(rs, 30 * 60);
  final int angsarRs = _floorDiv(rs % (30 * 60), 60);
  final int libdaRs = rs % 60;

  final int khan;
  final int pouichalip;
  if (angsarRs >= 15) {
    khan = 2 * reaseyRs + 1;
    pouichalip = 60 * (angsarRs - 15) + libdaRs;
  } else {
    khan = 2 * reaseyRs;
    pouichalip = 60 * angsarRs + libdaRs;
  }

  const List<int> multiplicities = <int>[35, 32, 27, 22, 13, 5];
  const List<int> chhayas = <int>[0, 35, 67, 94, 116, 129];
  final int multiplicity = (khan >= 0 && khan < 6) ? multiplicities[khan] : 0;
  final int chhaya = (khan >= 0 && khan < 6) ? chhayas[khan] : 134;

  final int q = _floorDiv(pouichalip * multiplicity, 900);
  final int pholAsLibda =
      (60 * _floorDiv(q + chhaya, 60)) + ((q + chhaya) % 60);

  return kaen <= 5 ? sunAverage - pholAsLibda : sunAverage + pholAsLibda;
}

// ------------------------------------------------------------- Khmer New Year

int _lunarDaysBetween(
  int fromMonth,
  int fromDay,
  int toMonth,
  int toDay,
  int beYear,
) {
  if (fromMonth == toMonth) return toDay - fromDay;
  if (toMonth > fromMonth) {
    int days = getNumberOfDayInKhmerMonth(fromMonth, beYear) - fromDay;
    for (int m = fromMonth + 1; m < toMonth; m++) {
      days += getNumberOfDayInKhmerMonth(m, beYear);
    }
    return days + toDay;
  }
  return -_lunarDaysBetween(toMonth, toDay, fromMonth, fromDay, beYear);
}

/// The days of Choul Chnam Thmey for a Gregorian year (three or four of them).
///
/// The Python reference builds this date with `strptime`, which rejects an hour
/// of 24 and makes the service return 500 for such years (1974, for example).
/// Here hour 24 simply rolls into the next day.
List<DateTime> khmerNewYearDays(int gregorianYear) {
  final SoriyatraLerngSak info = getSoriyatraLerngSak(
    gregorianYear + 544 - 1182,
  );
  final int numberOfDays = info.newYearDayAngsarIsZero ? 4 : 3;

  final DateTime epochLerngSak = _utc(
    gregorianYear,
    4,
    17,
    info.hour,
    info.minute,
  );

  final KhLunarDate khEpoch = findLunarDate(epochLerngSak);
  final int beYear = getMaybeBeYear(epochLerngSak);

  final int diffFromEpoch = _lunarDaysBetween(
    info.lunarDateLerngSakMonth,
    info.lunarDateLerngSakDay,
    khEpoch.month,
    khEpoch.day,
    beYear,
  );

  final DateTime start = _addDays(
    epochLerngSak,
    -(diffFromEpoch + numberOfDays - 1),
  );

  return List<DateTime>.generate(numberOfDays, (int i) => _addDays(start, i));
}

/// The instant the new year begins.
DateTime khmerNewYearMoment(int gregorianYear) =>
    khmerNewYearDays(gregorianYear).first;

int getAnimalYear(DateTime date) {
  final DateTime utcDate = date.isUtc
      ? date
      : _utc(date.year, date.month, date.day, date.hour, date.minute);
  final DateTime moment = khmerNewYearMoment(utcDate.year);
  return utcDate.isBefore(moment)
      ? (utcDate.year + 543 + 4) % 12
      : (utcDate.year + 544 + 4) % 12;
}

int getJolakSakarajYear(DateTime date) {
  final DateTime utcDate = date.isUtc
      ? date
      : _utc(date.year, date.month, date.day, date.hour, date.minute);
  final DateTime moment = khmerNewYearMoment(utcDate.year);
  return utcDate.isBefore(moment)
      ? utcDate.year + 543 - 1182
      : utcDate.year + 544 - 1182;
}

// ---------------------------------------------------------------- presentation

/// The `១៥កើត` style token for a lunar day index.
String lunarDayToken(int lunarDayIndex) =>
    '${toKhmerDigits((lunarDayIndex % 15) + 1)}'
    '${lunarDayIndex > 14 ? 'រោច' : 'កើត'}';

/// The full Khmer sentence, matching `/lunar-date/formatted/`.
String formatKhmerDate(DateTime date) {
  final KhLunarDate lunar = findLunarDate(date);
  final String weekday = khmerWeekdays[sundayFirstIndex(date)];
  final String animal = khmerAnimalYears[getAnimalYear(date)];
  final String era = khmerEraYears[getJolakSakarajYear(date) % 10];

  return 'ថ្ងៃ$weekday '
      '${lunarDayToken(lunar.day)} '
      'ខែ${lunarMonthName(lunar.month)} '
      'ឆ្នាំ$animal $era '
      'ពុទ្ធសករាជ ${toKhmerDigits(getBeYear(date))}';
}

const Set<String> _holyDayTokens = <String>{'៨កើត', '៨រោច', '១៥កើត', '១៥រោច'};

/// Buddhist holy day (ថ្ងៃសីល): the 8th and 15th of either fortnight, plus the
/// 14th waning when it closes a short month (the next day is the 1st waxing).
bool isBuddhistHolyDay(DateTime date) {
  final String today = lunarDayToken(findLunarDate(date).day);
  if (_holyDayTokens.contains(today)) return true;

  if (today != '១៤រោច') return false;
  final DateTime tomorrow = _addDays(
    date.isUtc ? date : _utc(date.year, date.month, date.day),
    1,
  );
  return lunarDayToken(findLunarDate(tomorrow).day) == '១កើត';
}
