import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noted/app.dart';
import 'package:noted/data/khmer_lunar.dart';
import 'package:noted/data/note_store.dart';
import 'package:noted/utils/khmer_text.dart';

void main() {
  // The aurora background animates forever, so pumpAndSettle would never
  // return — advance a fixed number of frames instead.
  Future<void> openCalendar(WidgetTester tester) async {
    await tester.pumpWidget(NotedApp(store: MemoryNoteStore()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Calendar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('renders the grid with computed lunar days',
      (WidgetTester tester) async {
    await openCalendar(tester);

    // Sunday-first weekday headers.
    expect(find.text('អា'), findsOneWidget);
    expect(find.text('ស'), findsOneWidget);

    // Today's own lunar token must appear somewhere in the grid.
    final DateTime today = DateTime.now();
    final String token = lunarDayToken(
      findLunarDate(DateTime.utc(today.year, today.month, today.day)).day,
    );
    expect(find.text(token), findsWidgets);
  });

  testWidgets('detail panel shows the computed Khmer sentence for today',
      (WidgetTester tester) async {
    await openCalendar(tester);

    final DateTime today = DateTime.now();
    final String sentence =
        formatKhmerDate(DateTime.utc(today.year, today.month, today.day));

    // The panel sits below the grid, off-screen at the default test size.
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();

    expect(find.text(sentence), findsOneWidget);
    expect(find.text('ថ្ងៃ${weekdayName(today)}'), findsOneWidget);
    expect(find.text('New note for today'), findsOneWidget);
  });

  testWidgets('month navigation moves the header without any loading state',
      (WidgetTester tester) async {
    await openCalendar(tester);

    final DateTime now = DateTime.now();
    final DateTime next = DateTime(now.year, now.month + 1);

    expect(
      find.text('${gregorianMonthName(now.month)} ${toKhmerDigits(now.year)}'),
      findsOneWidget,
    );
    // Computation is synchronous, so nothing should ever spin.
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(
          '${gregorianMonthName(next.month)} ${toKhmerDigits(next.year)}'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('header opens the picker and jumps to another year and month',
      (WidgetTester tester) async {
    await openCalendar(tester);

    final DateTime now = DateTime.now();
    final int targetYear = now.year - 3;

    // Tapping the month title opens the picker.
    await tester.tap(
      find.text('${gregorianMonthName(now.month)} ${toKhmerDigits(now.year)}'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('ខែ'), findsOneWidget);

    // Step the year back three times, then choose មករា (January).
    for (int i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Previous year'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.text(gregorianMonthName(1)).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('${gregorianMonthName(1)} ${toKhmerDigits(targetYear)}'),
      findsOneWidget,
    );
    // A far-away year must still compute, not fall back to an error.
    expect(find.text('Could not compute this month'), findsNothing);
  });

  testWidgets('year can be typed into the picker', (WidgetTester tester) async {
    await openCalendar(tester);

    final DateTime now = DateTime.now();
    await tester.tap(
      find.text('${gregorianMonthName(now.month)} ${toKhmerDigits(now.year)}'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The year field is prefilled with the current year in Latin digits.
    expect(find.widgetWithText(TextField, '${now.year}'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '1999');
    await tester.pump(const Duration(milliseconds: 300));

    // The Khmer rendering under the field tracks what was typed.
    expect(find.text(toKhmerDigits(1999)), findsWidgets);

    await tester.tap(find.text(gregorianMonthName(6)).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('${gregorianMonthName(6)} ${toKhmerDigits(1999)}'),
      findsOneWidget,
    );
  });

  testWidgets('picker year strip jumps directly to a tapped year',
      (WidgetTester tester) async {
    await openCalendar(tester);

    final DateTime now = DateTime.now();
    await tester.tap(
      find.text('${gregorianMonthName(now.month)} ${toKhmerDigits(now.year)}'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The strip is scrolled to the current year, so a neighbour is on screen.
    await tester.tap(find.text(toKhmerDigits(now.year + 1)).last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(gregorianMonthName(now.month)).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text(
          '${gregorianMonthName(now.month)} ${toKhmerDigits(now.year + 1)}'),
      findsOneWidget,
    );
  });

  testWidgets('the detail panel always describes a day in the visible month',
      (WidgetTester tester) async {
    await openCalendar(tester);

    // Step forward two months; the selection must follow, otherwise the panel
    // would describe a date that is not in the grid.
    await tester.tap(find.byTooltip('Next month'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Next month'));
    await tester.pump(const Duration(milliseconds: 300));

    final DateTime now = DateTime.now();
    final DateTime shown = DateTime(now.year, now.month + 2);
    final int lastDay = DateTime(shown.year, shown.month + 1, 0).day;
    final DateTime expected = DateTime(
      shown.year,
      shown.month,
      now.day.clamp(1, lastDay),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();

    expect(
      find.text(
        '${expected.day} ${gregorianMonthName(expected.month)} ${toKhmerDigits(expected.year)}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('today button returns to the current month',
      (WidgetTester tester) async {
    await openCalendar(tester);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pump();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Today'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final DateTime now = DateTime.now();
    expect(
      find.text('${gregorianMonthName(now.month)} ${toKhmerDigits(now.year)}'),
      findsOneWidget,
    );
  });
}
