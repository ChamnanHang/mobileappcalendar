import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noted/app.dart';
import 'package:noted/data/note_store.dart';
import 'package:noted/utils/khmer_text.dart';

void main() {
  // Fixed frame counts rather than pumpAndSettle, so a test that does leave
  // something animating fails on its assertions instead of timing out.
  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(NotedApp(store: MemoryNoteStore()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // The calendar is the first tab, so booting lands on it.
  Future<void> openCalendar(WidgetTester tester) => boot(tester);

  Future<void> openNotes(WidgetTester tester) async {
    await boot(tester);
    await tester.tap(find.text('Notes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  String monthLabel(DateTime month) =>
      '${gregorianMonthName(month.month)} ${toKhmerDigits(month.year)}';

  group('calendar swipe', () {
    testWidgets('flinging left advances a month', (WidgetTester tester) async {
      await openCalendar(tester);
      final DateTime now = DateTime.now();
      final DateTime next = DateTime(now.year, now.month + 1);

      expect(
        find.text(monthLabel(DateTime(now.year, now.month))),
        findsOneWidget,
      );

      // Fling the grid, not the header — the gesture lives on the grid so a
      // drag on the title still opens the month picker.
      await tester.fling(
        find.byType(Scaffold).last,
        const Offset(-300, 0),
        900,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(monthLabel(next)), findsOneWidget);
    });

    testWidgets('flinging right goes back a month', (
      WidgetTester tester,
    ) async {
      await openCalendar(tester);
      final DateTime now = DateTime.now();
      final DateTime previous = DateTime(now.year, now.month - 1);

      await tester.fling(find.byType(Scaffold).last, const Offset(300, 0), 900);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(monthLabel(previous)), findsOneWidget);
    });

    testWidgets('a slow drag with no fling velocity still changes month', (
      WidgetTester tester,
    ) async {
      await openCalendar(tester);
      final DateTime now = DateTime.now();
      final DateTime next = DateTime(now.year, now.month + 1);

      // Drag far, then pause before releasing so the velocity tracker has
      // nothing recent to estimate from — primaryVelocity comes back 0. This
      // is the case a velocity-only gate silently dropped: the user hauls the
      // grid most of the way across the screen and the month never changes.
      final Offset start = tester.getCenter(find.byType(Scaffold).last);
      final TestGesture gesture = await tester.startGesture(start);
      for (int i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(-30, 0));
        await tester.pump(const Duration(milliseconds: 40));
      }
      // The pause is what zeroes the velocity estimate.
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(monthLabel(next)), findsOneWidget);
    });

    testWidgets('a short drag does not change month', (
      WidgetTester tester,
    ) async {
      await openCalendar(tester);
      final DateTime now = DateTime.now();
      final String current = monthLabel(DateTime(now.year, now.month));

      // Under both gates: too slow to be a fling, too short to be a
      // deliberate drag — a stray sideways wobble during a vertical scroll.
      await tester.fling(find.byType(Scaffold).last, const Offset(-40, 0), 60);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(current), findsOneWidget);
    });

    testWidgets('swiping twice and back returns to the starting month', (
      WidgetTester tester,
    ) async {
      await openCalendar(tester);
      final DateTime now = DateTime.now();
      final String start = monthLabel(DateTime(now.year, now.month));

      for (int i = 0; i < 2; i++) {
        await tester.fling(
          find.byType(Scaffold).last,
          const Offset(-300, 0),
          900,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
      for (int i = 0; i < 2; i++) {
        await tester.fling(
          find.byType(Scaffold).last,
          const Offset(300, 0),
          900,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.text(start), findsOneWidget);
    });
  });

  group('expanding FAB', () {
    testWidgets('opens, then a tap outside closes it', (
      WidgetTester tester,
    ) async {
      await openNotes(tester);

      // Collapsed: the actions are laid out but not interactive.
      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Checklist'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);

      // Tapping the scrim, well away from the FAB, closes it.
      await tester.tapAt(const Offset(40, 120));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Still in the tree but fully faded out and non-interactive.
      final Opacity faded = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Checklist'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(faded.opacity, 0);
    });

    testWidgets('choosing Note opens the editor', (WidgetTester tester) async {
      await openNotes(tester);

      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Note'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Title'), findsOneWidget);
    });
  });

  group('shell', () {
    testWidgets('opens on the calendar', (WidgetTester tester) async {
      await boot(tester);
      final DateTime now = DateTime.now();

      expect(
        find.text(monthLabel(DateTime(now.year, now.month))),
        findsOneWidget,
      );
      // The note list is not built until its tab is first opened.
      expect(find.text('Noted'), findsNothing);

      await tester.tap(find.text('Notes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Noted'), findsOneWidget);
    });

    testWidgets('settles: nothing animates forever', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(NotedApp(store: MemoryNoteStore()));

      // Would time out if any widget kept a ticker running, which would also
      // keep the GPU busy and drain the battery on an idle screen.
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Noted'), findsOneWidget);
    });
  });
}
