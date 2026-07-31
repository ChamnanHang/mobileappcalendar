import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/khmer_holidays.dart';
import '../data/khmer_lunar.dart';
import '../data/notes_controller.dart';
import '../data/notes_scope.dart';
import '../models/note.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/date_keys.dart';
import '../utils/khmer_text.dart';
import '../utils/markdown_controller.dart';
import '../widgets/glass.dart';
import '../widgets/month_year_picker.dart';
import '../widgets/sheets.dart';
import 'editor_screen.dart';

/// Khmer lunar calendar: a month grid of Gregorian days annotated with their
/// lunar day (កើត / រោច), Buddhist holy days and Khmer New Year, plus a detail
/// panel for the selected day.
///
/// Everything is computed on-device by [findLunarDate] and friends, so there is
/// no loading state and no network involved.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  late DateTime _selected;

  /// Per-month derived data, recomputed only when the month changes.
  List<DateTime> _days = const <DateTime>[];
  Map<String, KhLunarDate> _lunar = const <String, KhLunarDate>{};
  Set<String> _holyDays = const <String>{};
  Map<String, List<KhmerHoliday>> _holidays =
      const <String, List<KhmerHoliday>>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = dayOnly(now);
    _recompute();
  }

  /// The 42 cells of a six-week, Sunday-first grid covering [_month].
  List<DateTime> _gridDays() {
    final DateTime first = DateTime(_month.year, _month.month);
    // DateTime.weekday is 1 = Monday … 7 = Sunday; % 7 puts Sunday in column 0.
    final DateTime start = first.subtract(Duration(days: first.weekday % 7));
    return List<DateTime>.generate(
      42,
      (int i) => DateTime(start.year, start.month, start.day + i),
    );
  }

  void _recompute() {
    final List<DateTime> days = _gridDays();

    try {
      final Map<String, KhLunarDate> lunar = <String, KhLunarDate>{};
      final Set<String> holy = <String>{};
      for (final DateTime day in days) {
        final DateTime utc = dayOnlyUtc(day);
        lunar[dateKey(day)] = findLunarDate(utc);
        if (isBuddhistHolyDay(utc)) holy.add(dateKey(day));
      }

      final Map<String, List<KhmerHoliday>> holidays =
          <String, List<KhmerHoliday>>{};
      for (final DateTime day in days) {
        final List<KhmerHoliday> found = holidaysOn(day);
        if (found.isNotEmpty) holidays[dateKey(day)] = found;
      }

      _days = days;
      _lunar = lunar;
      _holyDays = holy;
      _holidays = holidays;
      _error = null;
    } on Object catch (error) {
      _days = days;
      _lunar = const <String, KhLunarDate>{};
      _holyDays = const <String>{};
      _holidays = const <String, List<KhmerHoliday>>{};
      _error = '$error';
    }
  }

  /// Moves the selection into [month], keeping the same day number where the
  /// month is long enough. Without this the detail panel could describe a day
  /// that is not in the grid on screen.
  DateTime _carrySelectionInto(DateTime month) {
    final int lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, _selected.day.clamp(1, lastDay));
  }

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selected = _carrySelectionInto(_month);
      _recompute();
    });
  }

  void _select(DateTime day) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = dayOnly(day);
      if (day.month != _month.month || day.year != _month.year) {
        _month = DateTime(day.year, day.month);
        _recompute();
      }
    });
  }

  void _goToday() {
    final DateTime now = DateTime.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _selected = dayOnly(now);
      _recompute();
    });
  }

  /// Jump straight to any month/year rather than stepping one at a time.
  Future<void> _pickMonth() async {
    final DateTime? chosen = await showGlassSheet<DateTime>(
      context: context,
      builder: (BuildContext context) => MonthYearPicker(initial: _month),
    );
    if (chosen == null || !mounted) return;

    setState(() {
      _month = chosen;
      _selected = _carrySelectionInto(chosen);
      _recompute();
    });
  }

  @override
  Widget build(BuildContext context) {
    final NotesController notes = NotesScope.of(context);

    final Set<String> daysWithNotes = <String>{
      for (final Note note in notes.activeNotes) dateKey(note.createdAt),
    };

    final List<Note> notesOnSelected = notes.activeNotes
        .where((Note n) => isSameDay(n.createdAt, _selected))
        .toList()
      ..sort((Note a, Note b) => b.updatedAt.compareTo(a.updatedAt));

    final DateTime selectedUtc = dayOnlyUtc(_selected);
    final bool computed = _error == null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: <Widget>[
            _MonthHeader(
              month: _month,
              beYear: computed ? getBeYear(selectedUtc) : null,
              onPrev: () => _shiftMonth(-1),
              onNext: () => _shiftMonth(1),
              onToday: _goToday,
              onPickMonth: _pickMonth,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...<Widget>[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 14),
            ],
            const _WeekdayRow(),
            const SizedBox(height: 6),
            _MonthGrid(
              days: _days,
              month: _month,
              selected: _selected,
              lunar: _lunar,
              holyDays: _holyDays,
              holidays: _holidays,
              daysWithNotes: daysWithNotes,
              onSelect: _select,
            ),
            const SizedBox(height: 20),
            _DayDetailPanel(
              date: _selected,
              lunar: _lunar[dateKey(_selected)],
              formatted: computed ? formatKhmerDate(selectedUtc) : null,
              isHolyDay: _holyDays.contains(dateKey(_selected)),
              holidays:
                  _holidays[dateKey(_selected)] ?? const <KhmerHoliday>[],
              notes: notesOnSelected,
              onOpenNote: _openNote,
              onNewNote: isSameDay(_selected, DateTime.now())
                  ? () => _createNoteForToday(notes)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNote(Note note) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => EditorScreen(initial: note),
      ),
    );
  }

  Future<void> _createNoteForToday(NotesController notes) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            EditorScreen(initial: notes.draft(), autofocusBody: true),
      ),
    );
  }
}

// ------------------------------------------------------------------- header

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.beYear,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onPickMonth,
  });

  final DateTime month;
  final int? beYear;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPickMonth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) =>
                            AppColors.primaryGradient.createShader(bounds),
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          '${gregorianMonthName(month.month)} ${toKhmerDigits(month.year)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              text.headlineMedium?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: AppColors.textMid,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // One rich text rather than a Row: a Row of fixed-width Texts
                // cannot shrink and overflows on narrow phones.
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(text: _englishMonth(month)),
                      if (beYear != null) ...<InlineSpan>[
                        const TextSpan(text: '  ·  '),
                        TextSpan(
                          text: 'ពុទ្ធសករាជ ${toKhmerDigits(beYear!)}',
                          style: const TextStyle(color: AppColors.cyan),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: AppColors.textLow),
                ),
              ],
            ),
          ),
        ),
        GlassIconButton(
          icon: Icons.today_rounded,
          tooltip: 'Today',
          onTap: onToday,
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous month',
          onTap: onPrev,
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next month',
          onTap: onNext,
        ),
      ],
    );
  }

  static String _englishMonth(DateTime month) {
    const List<String> names = <String>[
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[month.month]} ${month.year}';
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < weekdayInitials.length; i++)
          Expanded(
            child: Center(
              child: Text(
                weekdayInitials[i],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: i == 0 ? AppColors.pink : AppColors.textLow,
                      fontSize: 11.5,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------------- grid

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.days,
    required this.month,
    required this.selected,
    required this.lunar,
    required this.holyDays,
    required this.holidays,
    required this.daysWithNotes,
    required this.onSelect,
  });

  final List<DateTime> days;
  final DateTime month;
  final DateTime selected;
  final Map<String, KhLunarDate> lunar;
  final Set<String> holyDays;
  final Map<String, List<KhmerHoliday>> holidays;
  final Set<String> daysWithNotes;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final DateTime today = dayOnly(DateTime.now());

    return Column(
      children: <Widget>[
        for (int week = 0; week < 6; week++)
          Row(
            children: <Widget>[
              for (int weekday = 0; weekday < 7; weekday++)
                Builder(
                  builder: (BuildContext context) {
                    final DateTime day = days[week * 7 + weekday];
                    final String key = dateKey(day);
                    return Expanded(
                      child: _DayCell(
                        date: day,
                        lunar: lunar[key],
                        inMonth: day.month == month.month,
                        isToday: isSameDay(day, today),
                        isSelected: isSameDay(day, selected),
                        isHolyDay: holyDays.contains(key),
                        isPublicHoliday: (holidays[key] ?? const <KhmerHoliday>[])
                            .any((KhmerHoliday h) => h.isPublicHoliday),
                        hasNote: daysWithNotes.contains(key),
                        onTap: () => onSelect(day),
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.lunar,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.isHolyDay,
    required this.isPublicHoliday,
    required this.hasNote,
    required this.onTap,
  });

  final DateTime date;
  final KhLunarDate? lunar;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final bool isHolyDay;
  final bool isPublicHoliday;
  final bool hasNote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool isSunday = date.weekday == DateTime.sunday;

    final Color accent = isPublicHoliday
        ? AppColors.pink
        : (isToday ? AppColors.violet : AppColors.cyan);

    final Color dayColor = !inMonth
        ? AppColors.textHigh.withValues(alpha: 0.20)
        : (isSunday ? AppColors.pink : AppColors.textHigh);

    return Padding(
      padding: const EdgeInsets.all(2.5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 0.82,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: isToday
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.violet.withValues(alpha: 0.34),
                        AppColors.cyan.withValues(alpha: 0.18),
                      ],
                    )
                  : null,
              color: isToday
                  ? null
                  : (isSelected
                      ? accent.withValues(alpha: 0.13)
                      : Colors.white
                          .withValues(alpha: inMonth ? 0.035 : 0.012)),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isSelected
                    ? accent.withValues(alpha: 0.75)
                    : (isToday
                        ? AppColors.violet.withValues(alpha: 0.55)
                        : AppColors.glassBorder),
                width: isSelected ? 1.6 : 1,
              ),
              boxShadow: isSelected || isToday
                  ? <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '${date.day}',
                  style: text.titleMedium?.copyWith(
                    color: dayColor,
                    fontSize: 15.5,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                SizedBox(
                  height: 13,
                  child: lunar == null
                      ? const SizedBox.shrink()
                      : Text(
                          lunarDayToken(lunar!.day),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: text.labelSmall?.copyWith(
                            fontSize: 9.5,
                            height: 1.1,
                            color: !inMonth
                                ? AppColors.textHigh.withValues(alpha: 0.16)
                                : (isHolyDay
                                    ? AppColors.amber
                                    : AppColors.textMid),
                          ),
                        ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (isHolyDay && inMonth) const _Dot(color: AppColors.amber),
                    if (isPublicHoliday && inMonth)
                      const _Dot(color: AppColors.pink),
                    if (hasNote && inMonth) const _Dot(color: AppColors.lime),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 1.2),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// -------------------------------------------------------------------- detail

class _DayDetailPanel extends StatelessWidget {
  const _DayDetailPanel({
    required this.date,
    required this.lunar,
    required this.formatted,
    required this.isHolyDay,
    required this.holidays,
    required this.notes,
    required this.onOpenNote,
    required this.onNewNote,
  });

  final DateTime date;
  final KhLunarDate? lunar;
  final String? formatted;
  final bool isHolyDay;
  final List<KhmerHoliday> holidays;
  final List<Note> notes;
  final ValueChanged<Note> onOpenNote;
  final VoidCallback? onNewNote;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return GlassPanel(
      radius: AppTheme.radiusLg,
      blur: 22,
      glow: holidays.any((KhmerHoliday h) => h.isPublicHoliday)
          ? AppColors.pink
          : AppColors.cyan,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('ថ្ងៃ${weekdayName(date)}', style: text.headlineSmall),
                    Text(
                      '${date.day} ${gregorianMonthName(date.month)} ${toKhmerDigits(date.year)}',
                      style: text.bodySmall?.copyWith(color: AppColors.textMid),
                    ),
                  ],
                ),
              ),
              if (lunar != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      lunarDayToken(lunar!.day),
                      style: text.headlineSmall?.copyWith(color: AppColors.cyan),
                    ),
                    Text(
                      'ខែ${lunarMonthName(lunar!.month)}',
                      style: text.bodySmall?.copyWith(color: AppColors.textMid),
                    ),
                  ],
                ),
            ],
          ),
          if (formatted != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(formatted!, style: text.bodyMedium?.copyWith(height: 1.6)),
          ],
          if (isHolyDay || holidays.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (isHolyDay)
                  const _Badge(
                    icon: Icons.brightness_2_rounded,
                    label: 'ថ្ងៃសីល',
                    color: AppColors.amber,
                  ),
                for (final KhmerHoliday holiday in holidays)
                  _Badge(
                    icon: holiday.isPublicHoliday
                        ? Icons.celebration_rounded
                        : Icons.local_florist_rounded,
                    label: holiday.khmer,
                    color: holiday.isPublicHoliday
                        ? AppColors.pink
                        : AppColors.textMid,
                  ),
              ],
            ),
            for (final KhmerHoliday holiday in holidays)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  holiday.isPublicHoliday
                      ? '${holiday.english} · public holiday'
                      : holiday.english,
                  style: text.labelSmall?.copyWith(color: AppColors.textLow),
                ),
              ),
          ],
          const SizedBox(height: 18),
          Divider(color: AppColors.glassBorder, height: 1),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Icon(Icons.sticky_note_2_outlined,
                  size: 15, color: AppColors.textLow),
              const SizedBox(width: 7),
              Text(
                notes.isEmpty
                    ? 'No notes on this day'
                    : '${notes.length} note${notes.length == 1 ? '' : 's'} on this day',
                style: text.labelSmall?.copyWith(color: AppColors.textLow),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            for (final Note note in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onOpenNote(note),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 3,
                        height: 26,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: AppColors.accentAt(note.accent),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              note.title.trim().isEmpty
                                  ? 'Untitled'
                                  : note.title.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall,
                            ),
                            if (note.preview.isNotEmpty)
                              Text(
                                stripMarkdown(note.preview),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelSmall
                                    ?.copyWith(color: AppColors.textLow),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.textLow),
                    ],
                  ),
                ),
              ),
          ],
          if (onNewNote != null) ...<Widget>[
            const SizedBox(height: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onNewNote,
              child: Row(
                children: <Widget>[
                  Icon(Icons.add_rounded, size: 17, color: AppColors.cyan),
                  const SizedBox(width: 8),
                  Text(
                    'New note for today',
                    style: text.bodyMedium?.copyWith(color: AppColors.cyan),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.textHigh, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.pink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
        border: Border.all(color: AppColors.pink.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, size: 17, color: AppColors.pink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Could not compute this month', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: text.labelSmall?.copyWith(color: AppColors.textLow),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
