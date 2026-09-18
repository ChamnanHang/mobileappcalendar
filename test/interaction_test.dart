import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noted/app.dart';
import 'package:noted/data/note_store.dart';
import 'package:noted/utils/khmer_text.dart';

void main() {
  // The aurora animates forever, so pumpAndSettle would never return —
  // advance a fixed number of frames instead.
  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(NotedApp(store: MemoryNoteStore()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openCalendar(WidgetTester tester) async {
    await boot(tester);
    await tester.tap(find.text('Calendar'));
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

    testWidgets('a slow drag does not change month', (
      WidgetTester tester,
    ) async {
      await openCalendar(tester);
      final DateTime now = DateTime.now();
      final String current = monthLabel(DateTime(now.year, now.month));

      // Below the fling threshold — a stray sideways drag during a scroll.
      await tester.fling(find.byType(Scaffold).last, const Offset(-120, 0), 60);
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
      await boot(tester);

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
      await boot(tester);

      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Note'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Title'), findsOneWidget);
    });
  });

  group('reduced motion', () {
    testWidgets('the aurora stops animating when the OS asks it to', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: NotedApp(store: MemoryNoteStore()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // With the aurora stopped there is no perpetual ticker, so the tree
      // settles — which it never does otherwise.
      await tester.pumpAndSettle();

      expect(find.text('Noted'), findsOneWidget);
    });
  });
}
