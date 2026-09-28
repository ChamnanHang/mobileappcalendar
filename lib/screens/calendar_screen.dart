import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/khmer_holidays.dart';
import '../data/khmer_lunar.dart';
import '../data/khmer_month.dart';
import '../data/notes_controller.dart';
import '../data/notes_scope.dart';
import '../data/reminders.dart';
import '../models/note.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/date_keys.dart';
import '../utils/khmer_text.dart';
import '../widgets/surface.dart';
import '../widgets/month_year_picker.dart';
import '../widgets/reminder_sheet.dart';
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
  /// Months are immutable once computed, so they are cached rather than
  /// recomputed every time the user steps between them.
  final KhmerMonthCache _months = KhmerMonthCache();

  late DateTime _month;
  late DateTime _selected;
  late KhmerMonth _data;

  /// Which direction the last month change moved, so the grid slides the
  /// way the user pushed it.
  int _direction = 1;

  // Derived from the note list. The controller notifies on every edit,
  // including ones made on the other tab, and this screen stays alive inside
  // the shell's IndexedStack — so these are rebuilt only when the underlying
  // list actually changes identity, not on every notification.
  List<Note>? _notesSource;
  Set<String> _daysWithNotes = const <String>{};

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = dayOnly(now);
    _data = _months.monthFor(_month);
    _warmNeighbours();
  }

  /// Computes the adjacent months off the critical path so a swipe or an
  /// arrow tap lands on a grid that is already built.
  void _warmNeighbours() {
    final DateTime target = _month;
    scheduleMicrotask(() {
      if (!mounted || target != _month) return;
      _months.precache(target);
    });
  }

  void _refreshNoteIndex(NotesController notes) {
    final List<Note> source = notes.activeNotes;
    if (identical(source, _notesSource)) return;
    _notesSource = source;
    _daysWithNotes = <String>{
      for (final Note note in source) dateKey(note.createdAt),
    };
  }

  /// Moves the selection into [month], keeping the same day number where the
  /// month is long enough. Without this the detail panel could describe a day
  /// that is not in the grid on screen.
  DateTime _carrySelectionInto(DateTime month) {
    final int lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, _selected.day.clamp(1, lastDay));
  }

  void _showMonth(DateTime month, {required int direction, DateTime? select}) {
    setState(() {
      _direction = direction;
      _month = DateTime(month.year, month.month);
      _data = _months.monthFor(_month);
      _selected = select ?? _carrySelectionInto(_month);
    });
    _warmNeighbours();
  }

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    _showMonth(
      DateTime(_month.year, _month.month + delta),
      direction: delta.isNegative ? -1 : 1,
    );
  }

  void _select(DateTime day) {
    HapticFeedback.selectionClick();
    final DateTime picked = dayOnly(day);
    if (picked.month != _month.month || picked.year != _month.year) {
      // Tapping a trailing or leading cell moves the whole grid with it.
      _showMonth(
        DateTime(picked.year, picked.month),
        direction: picked.isBefore(_month) ? -1 : 1,
        select: picked,
      );
      return;
    }
    setState(() => _selected = picked);
  }

  void _goToday() {
    HapticFeedback.selectionClick();
    final DateTime now = DateTime.now();
    final DateTime today = dayOnly(now);
    _showMonth(
      DateTime(now.year, now.month),
      direction: today.isBefore(_month) ? -1 : 1,
      select: today,
    );
  }

  /// Jump straight to any month/year rather than stepping one at a time.
  Future<void> _pickMonth() async {
    final DateTime? chosen = await showAppSheet<DateTime>(
      context: context,
      builder: (BuildContext context) => MonthYearPicker(initial: _month),
    );
    if (chosen == null || !mounted) return;
    _showMonth(chosen, direction: chosen.isBefore(_month) ? -1 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final NotesController notes = NotesScope.of(context);
    final MorningReminders? reminders = RemindersScope.maybeOf(context);
    _refreshNoteIndex(notes);

    final List<Note> notesOnSelected =
        notes.activeNotes
            .where((Note n) => isSameDay(n.createdAt, _selected))
            .toList()
          ..sort((Note a, Note b) => b.updatedAt.compareTo(a.updatedAt));

    final DateTime selectedUtc = dayOnlyUtc(_selected);
    final String selectedKey = dateKey(_selected);
    final bool computed = _data.computed;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            _MonthHeader(
              month: _month,
              beYear: computed ? getBeYear(selectedUtc) : null,
              onPrev: () => _shiftMonth(-1),
              onNext: () => _shiftMonth(1),
              onToday: _goToday,
              onPickMonth: _pickMonth,
              reminderOn: reminders?.settings.enabled ?? false,
              onReminder: reminders != null && reminders.supported
                  ? () => _openReminders(reminders)
                  : null,
            ),
            const SizedBox(height: 16),
            if (_data.error != null) ...<Widget>[
              _ErrorBanner(message: _data.error!),
              const SizedBox(height: 14),
            ],
            const _WeekdayRow(),
            const SizedBox(height: 6),
            _SwipeableMonth(
              month: _month,
              direction: _direction,
              onSwipe: _shiftMonth,
              child: _MonthGrid(
                key: ValueKey<String>('${_month.year}-${_month.month}'),
                data: _data,
                selected: _selected,
                daysWithNotes: _daysWithNotes,
                onSelect: _select,
              ),
            ),
            const SizedBox(height: 20),
            _DayDetailPanel(
              date: _selected,
              lunar: _data.lunar[selectedKey],
              formatted: computed ? formatKhmerDate(selectedUtc) : null,
              isHolyDay: _data.holyDays.contains(selectedKey),
              holidays: _data.holidaysOnKey(selectedKey),
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

  Future<void> _openReminders(MorningReminders reminders) async {
    await showAppSheet<void>(
      context: context,
      builder: (BuildContext context) => ReminderSheet(reminders: reminders),
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

/// Wraps the grid in a horizontal swipe gesture and slides between months.
///
/// Stepping a calendar with only the two chevrons is unusual on a phone;
/// swiping is what people reach for first.
class _SwipeableMonth extends StatefulWidget {
  const _SwipeableMonth({
    required this.month,
    required this.direction,
    required this.onSwipe,
    required this.child,
  });

  /// A flick past this speed changes month regardless of how far it travelled,
  /// in logical pixels per second. Low enough to feel responsive, high enough
  /// that a vertical scroll with a little sideways drift does not trigger it.
  static const double flingVelocity = 220;

  /// A slow drag past this fraction of the grid's width also changes month.
  ///
  /// Velocity alone is not enough to gate on. `DragEndDetails.primaryVelocity`
  /// is zero whenever the velocity tracker cannot form an estimate — a drag
  /// that pauses before release, some assistive-input paths, and synthetic
  /// events — and a deliberate drag halfway across the screen that then does
  /// nothing feels broken. Distance is the fallback every carousel uses.
  static const double minDragFraction = 0.22;

  final DateTime month;
  final int direction;
  final ValueChanged<int> onSwipe;
  final Widget child;

  @override
  State<_SwipeableMonth> createState() => _SwipeableMonthState();
}

class _SwipeableMonthState extends State<_SwipeableMonth> {
  /// Accumulated horizontal travel of the drag in progress.
  double _dragDx = 0;

  void _onStart(DragStartDetails _) => _dragDx = 0;

  void _onUpdate(DragUpdateDetails details) =>
      _dragDx += details.primaryDelta ?? 0;

  void _onEnd(DragEndDetails details) {
    final double travelled = _dragDx;
    _dragDx = 0;

    final double velocity = details.primaryVelocity ?? 0;
    // Dragging right (positive) reveals the previous month.
    if (velocity.abs() >= _SwipeableMonth.flingVelocity) {
      widget.onSwipe(velocity > 0 ? -1 : 1);
      return;
    }

    final double width = context.size?.width ?? 0;
    final double minDx = width * _SwipeableMonth.minDragFraction;
    if (minDx > 0 && travelled.abs() >= minDx) {
      widget.onSwipe(travelled > 0 ? -1 : 1);
    }
  }

  void _onCancel() => _dragDx = 0;

  @override
  Widget build(BuildContext context) {
    final ValueKey<String> currentKey = ValueKey<String>(
      '${widget.month.year}-${widget.month.month}',
    );

    return GestureDetector(
      // Only claims horizontal drags, so the surrounding vertical ListView
      // keeps working normally.
      onHorizontalDragStart: _onStart,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: _onCancel,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        // Outgoing and incoming grids are the same size, so they can share the
        // slot instead of resizing it mid-transition.
        layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[...previous, ?current],
        ),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final bool incoming = child.key == currentKey;
          final double from = incoming
              ? widget.direction * 0.12
              : widget.direction * -0.12;
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(from, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: widget.child,
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
    this.reminderOn = false,
    this.onReminder,
  });

  final DateTime month;
  final int? beYear;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onPickMonth;

  /// Whether the morning reminder is on, which fills the bell.
  final bool reminderOn;

  /// Opens the reminder settings; the bell is hidden when null.
  final VoidCallback? onReminder;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    final Widget buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // No gaps between the buttons: each 40dp circle already sits in a 48dp
        // touch target, and the Khmer month name needs the width.
        if (onReminder != null)
          CircleIconButton(
            icon: reminderOn
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            tooltip: reminderOn
                ? 'Morning reminder, on'
                : 'Morning reminder, off',
            active: reminderOn,
            onTap: onReminder,
          ),
        CircleIconButton(
          icon: Icons.today_rounded,
          tooltip: 'Today',
          onTap: onToday,
        ),
        CircleIconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous month',
          onTap: onPrev,
        ),
        CircleIconButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next month',
          onTap: onNext,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                button: true,
                label: 'Change month, currently ${_englishMonth(month)}',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPickMonth,
                  child: Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          '${gregorianMonthName(month.month)} ${toKhmerDigits(month.year)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.headlineMedium,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 20,
                        color: p.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            buttons,
          ],
        ),
        // Below the buttons rather than beside them, so the Buddhist-era year
        // gets the full width instead of being cut off. Also opens the picker;
        // the title's label already tells a screen reader which month it is.
        ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPickMonth,
            // One rich text rather than a Row: a Row of fixed-width Texts
            // cannot shrink and overflows on narrow phones.
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: _englishMonth(month)),
                  if (beYear != null) ...<InlineSpan>[
                    const TextSpan(text: '  ·  '),
                    TextSpan(text: 'ពុទ្ធសករាជ ${toKhmerDigits(beYear!)}'),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: p.textTertiary),
            ),
          ),
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
    final AppPalette p = context.palette;
    return Row(
      children: <Widget>[
        for (int i = 0; i < weekdayInitials.length; i++)
          Expanded(
            child: Center(
              child: Text(
                weekdayInitials[i],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: i == 0 ? p.holiday : p.textTertiary,
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
    super.key,
    required this.data,
    required this.selected,
    required this.daysWithNotes,
    required this.onSelect,
  });

  final KhmerMonth data;
  final DateTime selected;
  final Set<String> daysWithNotes;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<DateTime> days = data.days;
    if (days.isEmpty) return const SizedBox.shrink();
    final DateTime today = dayOnly(DateTime.now());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int week = 0; week < 6; week++)
          Row(
            children: <Widget>[
              for (int weekday = 0; weekday < 7; weekday++)
                Expanded(child: _buildCell(days[week * 7 + weekday], today)),
            ],
          ),
      ],
    );
  }

  Widget _buildCell(DateTime day, DateTime today) {
    final String key = dateKey(day);
    return _DayCell(
      date: day,
      lunar: data.lunar[key],
      inMonth: day.month == data.month.month && day.year == data.month.year,
      isToday: isSameDay(day, today),
      isSelected: isSameDay(day, selected),
      isHolyDay: data.holyDays.contains(key),
      holidays: data.holidaysOnKey(key),
      hasNote: daysWithNotes.contains(key),
      onTap: () => onSelect(day),
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
    required this.holidays,
    required this.hasNote,
    required this.onTap,
  });

  final DateTime date;
  final KhLunarDate? lunar;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final bool isHolyDay;
  final List<KhmerHoliday> holidays;
  final bool hasNote;
  final VoidCallback onTap;

  bool get _isPublicHoliday =>
      holidays.any((KhmerHoliday h) => h.isPublicHoliday);

  /// What a screen reader reads for this cell.
  ///
  /// Without this the whole grid announces as a wall of bare numbers, with no
  /// way to tell a holiday or the selected day from any other.
  String get _semanticLabel {
    final StringBuffer buffer = StringBuffer()
      ..write('${date.day} ${gregorianMonthName(date.month)} ${date.year}');
    if (isToday) buffer.write(', today');
    final KhLunarDate? moon = lunar;
    if (moon != null) {
      buffer.write(
        ', ${lunarDayToken(moon.day)} ខែ${lunarMonthName(moon.month)}',
      );
    }
    if (isHolyDay) buffer.write(', ថ្ងៃសីល');
    for (final KhmerHoliday holiday in holidays) {
      buffer.write(', ${holiday.english}');
      if (holiday.isPublicHoliday) buffer.write(' public holiday');
    }
    if (hasNote) buffer.write(', has notes');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final TextTheme text = Theme.of(context).textTheme;
    final bool isSunday = date.weekday == DateTime.sunday;
    final bool isPublicHoliday = _isPublicHoliday;

    final Color dayColor;
    if (!inMonth) {
      dayColor = p.textTertiary.withValues(alpha: 0.5);
    } else if (isToday) {
      dayColor = p.onAccent;
    } else if (isSunday || isPublicHoliday) {
      dayColor = p.holiday;
    } else {
      dayColor = p.textPrimary;
    }

    final Color lunarColor = !inMonth
        ? p.textTertiary.withValues(alpha: 0.4)
        : (isHolyDay ? p.holy : p.textTertiary);

    return Semantics(
      button: true,
      selected: isSelected,
      label: _semanticLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 0.82,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: isSelected ? p.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: isToday
                        ? BoxDecoration(color: p.accent, shape: BoxShape.circle)
                        : null,
                    child: Text(
                      '${date.day}',
                      maxLines: 1,
                      style: text.titleMedium?.copyWith(
                        color: dayColor,
                        fontSize: 15,
                        height: 1.1,
                        fontWeight: isToday || isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
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
                              height: 1.2,
                              color: lunarColor,
                            ),
                          ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (isHolyDay && inMonth) _Dot(color: p.holy),
                        if (isPublicHoliday && inMonth) _Dot(color: p.holiday),
                        if (hasNote && inMonth) _Dot(color: p.accent),
                      ],
                    ),
                  ),
                ],
              ),
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
    final AppPalette p = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    return SurfaceCard(
      radius: AppTheme.radiusLg,
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
                      style: text.bodySmall?.copyWith(color: p.textSecondary),
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
                      style: text.headlineSmall?.copyWith(color: p.accent),
                    ),
                    Text(
                      'ខែ${lunarMonthName(lunar!.month)}',
                      style: text.bodySmall?.copyWith(color: p.textSecondary),
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
                  _Badge(
                    icon: Icons.brightness_2_rounded,
                    label: 'ថ្ងៃសីល',
                    color: p.holy,
                  ),
                for (final KhmerHoliday holiday in holidays)
                  _Badge(
                    icon: holiday.isPublicHoliday
                        ? Icons.celebration_rounded
                        : Icons.local_florist_rounded,
                    label: holiday.khmer,
                    color: holiday.isPublicHoliday
                        ? p.holiday
                        : p.textSecondary,
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
                  style: text.labelSmall?.copyWith(color: p.textTertiary),
                ),
              ),
          ],
          const SizedBox(height: 18),
          Divider(color: p.border, height: 1),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Icon(
                Icons.sticky_note_2_outlined,
                size: 15,
                color: p.textTertiary,
              ),
              const SizedBox(width: 7),
              Text(
                notes.isEmpty
                    ? 'No notes on this day'
                    : '${notes.length} note${notes.length == 1 ? '' : 's'} on this day',
                style: text.labelSmall?.copyWith(color: p.textTertiary),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            for (final Note note in notes)
              Semantics(
                button: true,
                label: note.title.trim().isEmpty
                    ? 'Open untitled note'
                    : 'Open ${note.title.trim()}',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onOpenNote(note),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 3,
                          height: 26,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: NoteColors.at(note.accent),
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
                              if (note.plainPreview.isNotEmpty)
                                Text(
                                  note.plainPreview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.labelSmall?.copyWith(
                                    color: p.textTertiary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: p.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          if (onNewNote != null) ...<Widget>[
            const SizedBox(height: 6),
            Semantics(
              button: true,
              label: 'New note for today',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onNewNote,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.add_rounded, size: 17, color: p.accent),
                      const SizedBox(width: 8),
                      Text(
                        'New note for today',
                        style: text.bodyMedium?.copyWith(color: p.accent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: p.textPrimary,
              fontSize: 12,
            ),
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
    final AppPalette p = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, size: 17, color: p.holiday),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Could not compute this month', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: text.labelSmall?.copyWith(color: p.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
