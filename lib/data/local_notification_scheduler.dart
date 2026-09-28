import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
// The 10-year database: current rules for every zone at a quarter of the size
// of the full one, and reminders are never more than two months out.
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminders.dart';

/// The scheduler for this platform: real notifications on Android and iOS,
/// nothing elsewhere.
ReminderScheduler defaultReminderScheduler() =>
    LocalNotificationScheduler.platformSupported
    ? LocalNotificationScheduler()
    : const NoopReminderScheduler();

/// [ReminderScheduler] backed by flutter_local_notifications.
class LocalNotificationScheduler implements ReminderScheduler {
  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static const String _channelId = 'morning_reminder';

  /// Android status-bar icon: a white-on-transparent drawable. The launcher
  /// icon cannot be used — Android masks it to a solid white square.
  static const String _androidIcon = 'ic_notification';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _ready;

  @override
  bool get supported => platformSupported;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  Future<void> _ensureReady() {
    return _ready ??= _initialize().catchError((Object error) {
      // Let the next call try again rather than caching the failure.
      _ready = null;
      throw error;
    });
  }

  Future<void> _initialize() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(await _deviceLocation());
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_androidIcon),
        // Nothing is requested at start-up: the prompt appears only when the
        // user turns the reminder on, where it is obvious why it is asked.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  /// The device's IANA zone. If the name is not in the database, the first
  /// zone with the same current offset stands in — right for today, and only
  /// wrong across a daylight-saving change the device zone does not share.
  static Future<tz.Location> _deviceLocation() async {
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      return tz.getLocation(info.identifier);
    } on Object catch (error) {
      debugPrint('Unknown device time zone, matching by offset: $error');
      final DateTime now = DateTime.now();
      final int epochMs = now.millisecondsSinceEpoch;
      for (final tz.Location location in tz.timeZoneDatabase.locations.values) {
        if (location.timeZone(epochMs).offset == now.timeZoneOffset) {
          return location;
        }
      }
      return tz.UTC;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _ensureReady();
      if (_isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? android = _android;
        if (android == null) return false;
        // Android 13+ shows the system prompt; older versions have no runtime
        // permission and report whether the user has switched the app's
        // notifications off in Settings.
        final bool? granted = await android.requestNotificationsPermission();
        return granted ?? await android.areNotificationsEnabled() ?? false;
      }
      return await _ios?.requestPermissions(alert: true, sound: true) ?? false;
    } on Object catch (error) {
      // Android refuses a second request while the first prompt is still
      // open. Treat any failure as "not granted" rather than leaving the
      // switch waiting on an exception.
      debugPrint('Notification permission request failed: $error');
      return false;
    }
  }

  @override
  Future<bool> exactTimingAllowed() async {
    if (!_isAndroid) return true;
    try {
      await _ensureReady();
      return await _android?.canScheduleExactNotifications() ?? true;
    } on Object catch (error) {
      debugPrint('Could not check exact alarm access: $error');
      return true;
    }
  }

  @override
  Future<void> requestExactTiming() async {
    if (!_isAndroid) return;
    await _ensureReady();
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await _ensureReady();
    // Pending only: a reminder already showing in the notification shade
    // stays there when the app is opened and the window is rebuilt.
    await _plugin.cancelAllPendingNotifications();

    // Exact where the OS allows it without asking — below Android 12 always,
    // on 12 and 13 through the declared SCHEDULE_EXACT_ALARM. Android 14
    // denies that by default, and an inexact alarm there still arrives within
    // an hour of its time.
    final AndroidScheduleMode mode = await exactTimingAllowed()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    for (final PlannedReminder reminder in reminders) {
      final tz.TZDateTime when = tz.TZDateTime(
        tz.local,
        reminder.at.year,
        reminder.at.month,
        reminder.at.day,
        reminder.at.hour,
        reminder.at.minute,
      );
      // The plugin rejects a time in the past, which the first reminder can
      // become if the plan was made in the last moments before it.
      if (!when.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: reminder.id,
        scheduledDate: when,
        title: reminder.digest.title,
        body: reminder.digest.body,
        notificationDetails: _details(reminder),
        androidScheduleMode: mode,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _ensureReady();
    await _plugin.cancelAllPendingNotifications();
  }

  NotificationDetails _details(PlannedReminder reminder) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Morning reminder',
        channelDescription:
            "Today's Khmer date, and holy days and holidays today and "
            'tomorrow.',
        icon: _androidIcon,
        color: const Color(0xFF4F46E5),
        category: AndroidNotificationCategory.reminder,
        // The body can run to two lines; the collapsed view shows one.
        styleInformation: BigTextStyleInformation(
          reminder.digest.body,
          contentTitle: reminder.digest.title,
        ),
      ),
      iOS: const DarwinNotificationDetails(threadIdentifier: _channelId),
    );
  }
}
