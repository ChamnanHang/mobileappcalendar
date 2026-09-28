/// The daily morning reminder: its settings, the plan of upcoming
/// notifications, and the controller that keeps the OS schedule in step.
///
/// Neither Android nor iOS will run app code at 7am to work out what the
/// notification should say, and a repeating notification can only repeat the
/// same text. The calendar is deterministic, though, so each morning's text is
/// computed ahead of time and scheduled as its own one-shot notification. The
/// window rolls forward every time the app is opened.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/date_keys.dart';
import 'morning_digest.dart';

// ------------------------------------------------------------------- settings

@immutable
class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  }) : assert(hour >= 0 && hour < 24),
       assert(minute >= 0 && minute < 60);

  /// Off until the user turns it on: both platforms need a permission, and it
  /// should be asked for when the user shows they want the reminder.
  static const ReminderSettings defaults = ReminderSettings(
    enabled: false,
    hour: 7,
    minute: 0,
  );

  final bool enabled;
  final int hour;
  final int minute;

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.enabled == enabled &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(enabled, hour, minute);
}

abstract class ReminderSettingsStore {
  Future<ReminderSettings> load();
  Future<void> save(ReminderSettings settings);
}

class PrefsReminderSettingsStore implements ReminderSettingsStore {
  static const String _enabledKey = 'noted.reminder.enabled';
  static const String _minuteOfDayKey = 'noted.reminder.minuteOfDay';

  @override
  Future<ReminderSettings> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool enabled = prefs.getBool(_enabledKey) ?? false;
      final int minuteOfDay =
          prefs.getInt(_minuteOfDayKey) ??
          ReminderSettings.defaults.hour * 60 +
              ReminderSettings.defaults.minute;
      final int clamped = minuteOfDay.clamp(0, 24 * 60 - 1);
      return ReminderSettings(
        enabled: enabled,
        hour: clamped ~/ 60,
        minute: clamped % 60,
      );
    } on Object catch (error) {
      debugPrint('Could not read reminder settings: $error');
      return ReminderSettings.defaults;
    }
  }

  @override
  Future<void> save(ReminderSettings settings) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, settings.enabled);
      await prefs.setInt(_minuteOfDayKey, settings.hour * 60 + settings.minute);
    } on Object catch (error) {
      debugPrint('Could not save reminder settings: $error');
    }
  }
}

class MemoryReminderSettingsStore implements ReminderSettingsStore {
  MemoryReminderSettingsStore([this.value = ReminderSettings.defaults]);

  ReminderSettings value;

  @override
  Future<ReminderSettings> load() async => value;

  @override
  Future<void> save(ReminderSettings settings) async => value = settings;
}

// ----------------------------------------------------------------- scheduling

/// One morning's notification, at a local wall-clock time.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.digest,
  });

  final int id;

  /// Local date and time, e.g. 7:00 on the day in question. Deliberately a
  /// wall-clock value: the scheduler resolves it in the device's time zone.
  final DateTime at;

  final MorningDigest digest;
}

/// How far ahead to schedule.
///
/// iOS keeps at most 64 pending local notifications per app and silently
/// drops the rest, so this stays under that with room to spare. Opening the
/// app at any point in the next two months moves the window forward again.
const int reminderHorizonDays = 60;

/// The date of the first reminder due after [now]: today if [hour]:[minute]
/// is still ahead, tomorrow otherwise.
DateTime firstReminderDate({
  required DateTime now,
  required int hour,
  required int minute,
}) {
  final DateTime todayAt = DateTime(now.year, now.month, now.day, hour, minute);
  return todayAt.isAfter(now)
      ? dayOnly(now)
      : DateTime(now.year, now.month, now.day + 1);
}

/// The next [days] reminders from [now], one per morning.
List<PlannedReminder> planReminders({
  required DateTime now,
  required int hour,
  required int minute,
  int days = reminderHorizonDays,
}) {
  final DateTime first = firstReminderDate(
    now: now,
    hour: hour,
    minute: minute,
  );

  return List<PlannedReminder>.generate(days, (int i) {
    // Built from calendar fields rather than by adding Durations, so a
    // daylight-saving change keeps the reminder at the same wall-clock time.
    final DateTime at = DateTime(
      first.year,
      first.month,
      first.day + i,
      hour,
      minute,
    );
    return PlannedReminder(
      // Stable per date rather than per position, so a day keeps its id as
      // the window rolls forward.
      id: at.year * 10000 + at.month * 100 + at.day,
      at: at,
      digest: buildMorningDigest(at),
    );
  }, growable: false);
}

/// The OS side of reminders. The real one wraps flutter_local_notifications;
/// tests and unsupported platforms use a fake or a no-op.
abstract class ReminderScheduler {
  /// Whether this platform can show scheduled notifications at all.
  bool get supported;

  /// Asks the user for permission to notify. True if granted.
  Future<bool> requestPermission();

  /// Whether reminders will arrive on the minute. Android 14 and later deny
  /// exact alarms by default, and then a reminder may be up to an hour late.
  Future<bool> exactTimingAllowed();

  /// Opens the system screen where exact timing can be allowed.
  Future<void> requestExactTiming();

  /// Replaces everything pending with [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);

  Future<void> cancelAll();
}

class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  bool get supported => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> exactTimingAllowed() async => true;

  @override
  Future<void> requestExactTiming() async {}

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {}

  @override
  Future<void> cancelAll() async {}
}

// ----------------------------------------------------------------- controller

enum EnableResult { enabled, permissionDenied, unsupported }

class MorningReminders extends ChangeNotifier {
  MorningReminders({
    required this._scheduler,
    ReminderSettingsStore? store,
    DateTime Function()? clock,
  }) : _store = store ?? PrefsReminderSettingsStore(),
       _clock = clock ?? DateTime.now;

  final ReminderScheduler _scheduler;
  final ReminderSettingsStore _store;
  final DateTime Function() _clock;

  ReminderSettings _settings = ReminderSettings.defaults;
  ReminderSettings get settings => _settings;

  bool get supported => _scheduler.supported;

  /// The first date of the window last handed to the OS, so a resume on the
  /// same day does not reschedule sixty notifications for nothing.
  String? _scheduledFrom;

  /// Operations run one at a time. Toggling quickly would otherwise let a
  /// cancel land after the schedule it was meant to precede.
  Future<void> _queue = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() task) {
    final Future<T> result = _queue.then((_) => task());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> init() => _serial(() async {
    _settings = await _store.load();
    notifyListeners();
    // Always rebuild on launch: the time zone or the app's own logic may have
    // changed since the last schedule was written.
    if (_settings.enabled) await _apply();
  });

  /// Rolls the window forward if the day has changed since it was scheduled.
  /// Cheap to call on every resume.
  Future<void> refresh() => _serial(() async {
    if (!_settings.enabled) return;
    final String from = dateKey(
      firstReminderDate(
        now: _clock(),
        hour: _settings.hour,
        minute: _settings.minute,
      ),
    );
    if (from != _scheduledFrom) await _apply();
  });

  Future<EnableResult> setEnabled(bool enabled) => _serial(() async {
    if (!enabled) {
      await _save(_settings.copyWith(enabled: false));
      _scheduledFrom = null;
      try {
        await _scheduler.cancelAll();
      } on Object catch (error) {
        // Saved as off either way; the next launch, which schedules nothing
        // while off, is no worse than before.
        debugPrint('Could not cancel reminders: $error');
      }
      return EnableResult.enabled;
    }
    if (!_scheduler.supported) return EnableResult.unsupported;
    if (!await _scheduler.requestPermission()) {
      return EnableResult.permissionDenied;
    }
    await _save(_settings.copyWith(enabled: true));
    await _apply();
    return EnableResult.enabled;
  });

  Future<void> setTime(int hour, int minute) => _serial(() async {
    await _save(_settings.copyWith(hour: hour, minute: minute));
    if (_settings.enabled) await _apply();
  });

  /// Rebuilds the schedule now — after exact timing is granted, for example,
  /// so the pending reminders pick up the precise alarm mode.
  Future<void> reschedule() => _serial(() async {
    if (_settings.enabled) await _apply();
  });

  Future<bool> exactTimingAllowed() => _scheduler.exactTimingAllowed();

  Future<void> requestExactTiming() => _scheduler.requestExactTiming();

  /// What tomorrow morning's notification will say.
  MorningDigest previewTomorrow() {
    final DateTime now = _clock();
    return buildMorningDigest(DateTime(now.year, now.month, now.day + 1));
  }

  Future<void> _save(ReminderSettings next) async {
    _settings = next;
    notifyListeners();
    await _store.save(next);
  }

  Future<void> _apply() async {
    final List<PlannedReminder> plan = planReminders(
      now: _clock(),
      hour: _settings.hour,
      minute: _settings.minute,
    );
    try {
      await _scheduler.replaceAll(plan);
      _scheduledFrom = dateKey(plan.first.at);
    } on Object catch (error) {
      // A failed schedule must not take the app down; the next launch or
      // resume tries again.
      debugPrint('Could not schedule reminders: $error');
      _scheduledFrom = null;
    }
  }
}

class RemindersScope extends InheritedNotifier<MorningReminders> {
  const RemindersScope({
    super.key,
    required MorningReminders controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller, or null where reminders are not wired in.
  static MorningReminders? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RemindersScope>()?.notifier;
}
