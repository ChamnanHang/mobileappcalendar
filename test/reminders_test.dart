import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noted/app.dart';
import 'package:noted/data/khmer_lunar.dart';
import 'package:noted/data/morning_digest.dart';
import 'package:noted/data/note_store.dart';
import 'package:noted/data/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what the controller asks the OS to do.
class FakeScheduler implements ReminderScheduler {
  FakeScheduler({this.grant = true, this.supported = true, this.exact = true});

  bool grant;
  bool exact;
  bool failNext = false;

  @override
  final bool supported;

  int permissionRequests = 0;
  int cancels = 0;
  final List<List<PlannedReminder>> schedules = <List<PlannedReminder>>[];

  List<PlannedReminder> get last => schedules.last;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<bool> exactTimingAllowed() async => exact;

  @override
  Future<void> requestExactTiming() async {}

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    if (failNext) {
      failNext = false;
      throw StateError('scheduling failed');
    }
    schedules.add(reminders);
  }

  @override
  Future<void> cancelAll() async => cancels++;
}

void main() {
  group('morning digest', () {
    test('title is the Khmer weekday and lunar date', () {
      final MorningDigest digest = buildMorningDigest(DateTime(2026, 9, 28));
      // 28 September 2026 is a Monday, ២រោច ខែភទ្របទ.
      expect(digest.title, 'ថ្ងៃច័ន្ទ ២រោច ខែភទ្របទ');
    });

    test("names tomorrow's public holiday", () {
      // Constitution Day is fixed on 24 September.
      final MorningDigest digest = buildMorningDigest(DateTime(2026, 9, 23));
      final List<String> lines = digest.body.split('\n');

      expect(
        lines,
        contains(
          predicate<String>(
            (String l) =>
                l.startsWith('Tomorrow:') && l.contains('Constitution Day'),
          ),
        ),
      );
    });

    test('names a holy day today and tomorrow', () {
      final DateTime holy = DateTime(2026, 9, 26);
      expect(isBuddhistHolyDay(DateTime.utc(2026, 9, 26)), isTrue);

      final String eve = buildMorningDigest(
        holy.subtract(const Duration(days: 1)),
      ).body;
      final String day = buildMorningDigest(holy).body;

      expect(eve, contains('Tomorrow: ថ្ងៃសីល'));
      expect(day, contains('Today: ថ្ងៃសីល'));
    });

    test('says so when neither day has anything on', () {
      // Search rather than hard-code, so a holiday-table change cannot turn
      // this into a false failure.
      DateTime day = DateTime(2026, 11, 1);
      while (eventsOn(day).isNotEmpty ||
          eventsOn(day.add(const Duration(days: 1))).isNotEmpty) {
        day = day.add(const Duration(days: 1));
      }

      expect(buildMorningDigest(day).body, quietDaysLine);
    });
  });

  group('planReminders', () {
    test('starts today when the time is still ahead', () {
      final List<PlannedReminder> plan = planReminders(
        now: DateTime(2026, 9, 28, 6, 30),
        hour: 7,
        minute: 0,
      );

      expect(plan, hasLength(reminderHorizonDays));
      expect(plan.first.at, DateTime(2026, 9, 28, 7));
      expect(plan.last.at, DateTime(2026, 11, 26, 7));
    });

    test('starts tomorrow once the time has passed', () {
      final List<PlannedReminder> plan = planReminders(
        now: DateTime(2026, 9, 28, 7),
        hour: 7,
        minute: 0,
      );

      expect(plan.first.at, DateTime(2026, 9, 29, 7));
    });

    test('one per morning, unique ids, across a year boundary', () {
      final List<PlannedReminder> plan = planReminders(
        now: DateTime(2026, 12, 31, 8),
        hour: 6,
        minute: 45,
      );

      expect(plan.first.at, DateTime(2027, 1, 1, 6, 45));
      expect(plan.first.id, 20270101);
      expect(plan.map((PlannedReminder r) => r.id).toSet(), hasLength(60));
      for (int i = 1; i < plan.length; i++) {
        final DateTime prev = plan[i - 1].at;
        expect(
          plan[i].at,
          DateTime(prev.year, prev.month, prev.day + 1, 6, 45),
        );
      }
    });

    test("each reminder carries that morning's digest", () {
      final List<PlannedReminder> plan = planReminders(
        now: DateTime(2026, 9, 22, 12),
        hour: 7,
        minute: 0,
        days: 5,
      );

      for (final PlannedReminder r in plan) {
        expect(r.digest.body, buildMorningDigest(r.at).body);
        expect(r.digest.title, buildMorningDigest(r.at).title);
      }
    });
  });

  group('MorningReminders', () {
    late FakeScheduler scheduler;
    late MemoryReminderSettingsStore store;
    late DateTime now;

    MorningReminders make() =>
        MorningReminders(scheduler: scheduler, store: store, clock: () => now);

    setUp(() {
      scheduler = FakeScheduler();
      store = MemoryReminderSettingsStore();
      now = DateTime(2026, 9, 28, 9);
    });

    test('is off by default and schedules nothing', () async {
      final MorningReminders r = make();
      await r.init();

      expect(r.settings, ReminderSettings.defaults);
      expect(scheduler.schedules, isEmpty);
      expect(scheduler.permissionRequests, 0);
    });

    test('turning it on asks, saves and schedules 60 mornings', () async {
      final MorningReminders r = make();
      await r.init();

      expect(await r.setEnabled(true), EnableResult.enabled);

      expect(scheduler.permissionRequests, 1);
      expect(store.value.enabled, isTrue);
      expect(scheduler.last, hasLength(60));
      expect(scheduler.last.first.at, DateTime(2026, 9, 29, 7));
    });

    test('a refused permission leaves it off', () async {
      scheduler.grant = false;
      final MorningReminders r = make();
      await r.init();

      expect(await r.setEnabled(true), EnableResult.permissionDenied);

      expect(r.settings.enabled, isFalse);
      expect(store.value.enabled, isFalse);
      expect(scheduler.schedules, isEmpty);
    });

    test('reports an unsupported platform without asking', () async {
      scheduler = FakeScheduler(supported: false);
      final MorningReminders r = make();
      await r.init();

      expect(await r.setEnabled(true), EnableResult.unsupported);
      expect(scheduler.permissionRequests, 0);
    });

    test('changing the time reschedules only while on', () async {
      final MorningReminders r = make();
      await r.init();

      await r.setTime(6, 30);
      expect(store.value.hour, 6);
      expect(store.value.minute, 30);
      expect(scheduler.schedules, isEmpty);

      await r.setEnabled(true);
      await r.setTime(5, 15);
      expect(scheduler.last.first.at, DateTime(2026, 9, 29, 5, 15));
    });

    test('turning it off cancels what is pending', () async {
      final MorningReminders r = make();
      await r.init();
      await r.setEnabled(true);

      await r.setEnabled(false);

      expect(scheduler.cancels, 1);
      expect(store.value.enabled, isFalse);
    });

    test('a stored "on" reschedules at launch', () async {
      store.value = const ReminderSettings(enabled: true, hour: 7, minute: 0);
      final MorningReminders r = make();
      await r.init();

      expect(scheduler.schedules, hasLength(1));
      expect(scheduler.permissionRequests, 0);
    });

    test('refresh rolls the window only when the day moves', () async {
      store.value = const ReminderSettings(enabled: true, hour: 7, minute: 0);
      final MorningReminders r = make();
      await r.init();

      now = DateTime(2026, 9, 28, 18);
      await r.refresh();
      expect(scheduler.schedules, hasLength(1));

      now = DateTime(2026, 9, 29, 9);
      await r.refresh();
      expect(scheduler.schedules, hasLength(2));
      expect(scheduler.last.first.at, DateTime(2026, 9, 30, 7));
    });

    test('a failed schedule is retried on the next refresh', () async {
      store.value = const ReminderSettings(enabled: true, hour: 7, minute: 0);
      scheduler.failNext = true;
      final MorningReminders r = make();
      await r.init();
      expect(scheduler.schedules, isEmpty);

      await r.refresh();
      expect(scheduler.schedules, hasLength(1));
    });

    test('rapid toggles apply in order', () async {
      final MorningReminders r = make();
      await r.init();

      final Future<EnableResult> on = r.setEnabled(true);
      final Future<EnableResult> off = r.setEnabled(false);
      await Future.wait(<Future<EnableResult>>[on, off]);

      expect(r.settings.enabled, isFalse);
      expect(scheduler.schedules, hasLength(1));
      expect(scheduler.cancels, 1);
    });
  });

  test('settings survive a restart', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final PrefsReminderSettingsStore store = PrefsReminderSettingsStore();

    await store.save(const ReminderSettings(enabled: true, hour: 6, minute: 5));

    expect(
      await PrefsReminderSettingsStore().load(),
      const ReminderSettings(enabled: true, hour: 6, minute: 5),
    );
  });

  group('reminder sheet', () {
    Future<FakeScheduler> boot(
      WidgetTester tester, {
      FakeScheduler? scheduler,
    }) async {
      final FakeScheduler fake = scheduler ?? FakeScheduler();
      await tester.pumpWidget(
        NotedApp(
          store: MemoryNoteStore(),
          reminderScheduler: fake,
          reminderSettings: MemoryReminderSettingsStore(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return fake;
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Morning reminder, off'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('the bell turns the reminder on', (WidgetTester tester) async {
      final FakeScheduler fake = await boot(tester);
      await openSheet(tester);

      expect(find.text('Morning reminder'), findsOneWidget);
      expect(find.text('TOMORROW MORNING'), findsOneWidget);
      // Default time, formatted for the locale.
      expect(find.text('7:00 AM'), findsWidgets);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fake.schedules, hasLength(1));
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.byTooltip('Morning reminder, on'), findsOneWidget);
    });

    testWidgets('says what to do when notifications are blocked', (
      WidgetTester tester,
    ) async {
      await boot(tester, scheduler: FakeScheduler(grant: false));
      await openSheet(tester);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Notifications are turned off'), findsOne);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('offers exact timing when Android would be late', (
      WidgetTester tester,
    ) async {
      await boot(tester, scheduler: FakeScheduler(exact: false));
      await openSheet(tester);
      expect(find.text('Allow exact time'), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Allow exact time'), findsOneWidget);
    });

    testWidgets('no bell where reminders are unsupported', (
      WidgetTester tester,
    ) async {
      await boot(tester, scheduler: FakeScheduler(supported: false));

      expect(find.byTooltip('Morning reminder, off'), findsNothing);
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    });
  });
}
