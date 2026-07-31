import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noted/app.dart';
import 'package:noted/data/note_store.dart';
import 'package:noted/data/notes_controller.dart';
import 'package:noted/models/note.dart';
import 'package:noted/utils/markdown_controller.dart';

void main() {
  group('NotesController', () {
    test('seeds notes on first launch', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();

      expect(c.loading, isFalse);
      expect(c.visibleNotes, isNotEmpty);
    });

    test('loads persisted notes instead of seeding', () async {
      final Note note = Note(
        id: 'a',
        title: 'Saved',
        body: 'body',
        kind: NoteKind.text,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final NotesController c =
          NotesController(store: MemoryNoteStore(<Note>[note]));
      await c.init();

      expect(c.visibleNotes.single.title, 'Saved');
    });

    test('pinned notes sort above newer notes', () async {
      // Seeded explicitly: the default welcome note is itself pinned, which
      // would otherwise win the tie on recency.
      final NotesController c = NotesController(
        store: MemoryNoteStore(<Note>[
          Note(
            id: 'old',
            title: 'Old but pinned',
            body: 'x',
            kind: NoteKind.text,
            pinned: true,
            createdAt: DateTime(2020),
            updatedAt: DateTime(2020),
          ),
          Note(
            id: 'new',
            title: 'New but unpinned',
            body: 'y',
            kind: NoteKind.text,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ]),
      );
      await c.init();

      expect(c.visibleNotes.map((Note n) => n.id).toList(),
          <String>['old', 'new']);
    });

    test('empty notes are never persisted', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      final int before = c.visibleNotes.length;

      c.upsert(Note.empty());

      expect(c.visibleNotes.length, before);
    });

    test('search matches title, body, tags and checklist items', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      c.upsert(Note(
        id: 'x',
        title: 'Roadmap',
        body: 'ship the beta',
        kind: NoteKind.text,
        tags: <String>['planning'],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));

      c.search('beta');
      expect(c.visibleNotes.single.id, 'x');

      c.search('planning');
      expect(c.visibleNotes.single.id, 'x');

      c.search('nothing-here');
      expect(c.visibleNotes, isEmpty);
    });

    test('archived notes leave the main list and land in the archive', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      final String id = c.visibleNotes.first.id;

      c.setArchived(id, true);
      expect(c.visibleNotes.any((Note n) => n.id == id), isFalse);

      c.setFilter(NoteFilter.archive);
      expect(c.visibleNotes.single.id, id);
    });

    test('archiving clears the pin', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      final Note pinned = c.visibleNotes.firstWhere((Note n) => n.pinned);

      c.setArchived(pinned.id, true);

      expect(c.byId(pinned.id)!.pinned, isFalse);
    });

    test('favourites filter only shows favourites', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      final String id = c.visibleNotes.first.id;
      c.toggleFavorite(id);

      c.setFilter(NoteFilter.favorites);

      expect(c.visibleNotes.every((Note n) => n.favorite), isTrue);
      expect(c.visibleNotes.any((Note n) => n.id == id), isTrue);
    });

    test('tag filter narrows the list and toggles off', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      final String tag = c.allTags.first;

      c.toggleTagFilter(tag);
      expect(c.visibleNotes.every((Note n) => n.tags.contains(tag)), isTrue);

      c.toggleTagFilter(tag);
      expect(c.activeTag, isNull);
    });

    test('checklist toggle flips a single item', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      final Note list =
          c.visibleNotes.firstWhere((Note n) => n.kind == NoteKind.checklist);
      final ChecklistItem item = list.items.first;

      c.toggleChecklistItem(list.id, item.id);

      expect(c.byId(list.id)!.items.first.done, !item.done);
    });

    test('delete then restore round-trips', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      final Note note = c.visibleNotes.first;

      c.delete(note.id);
      expect(c.byId(note.id), isNull);

      c.restore(note);
      expect(c.byId(note.id), isNotNull);
    });
  });

  group('persistence', () {
    test('notes survive a save/load round-trip', () async {
      final MemoryNoteStore store = MemoryNoteStore();
      final NotesController first = NotesController(store: store);
      await first.init();
      first.upsert(Note(
        id: 'keep',
        title: 'Persisted',
        body: '**bold**',
        kind: NoteKind.text,
        tags: <String>['t'],
        folder: 'Work',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));
      await first.flush();

      final NotesController second = NotesController(store: store);
      await second.init();

      final Note? restored = second.byId('keep');
      expect(restored, isNotNull);
      expect(restored!.title, 'Persisted');
      expect(restored.folder, 'Work');
      expect(restored.tags, <String>['t']);
    });

    test('Note json round-trips every field', () {
      final Note note = Note(
        id: 'id',
        title: 'T',
        body: 'B',
        kind: NoteKind.checklist,
        items: <ChecklistItem>[
          const ChecklistItem(id: 'i', text: 'item', done: true),
        ],
        tags: <String>['a', 'b'],
        folder: 'F',
        accent: 3,
        pinned: true,
        favorite: true,
        archived: true,
        createdAt: DateTime(2026, 1, 2),
        updatedAt: DateTime(2026, 3, 4),
      );

      final Note copy = Note.fromJson(note.toJson());

      expect(copy.id, note.id);
      expect(copy.kind, NoteKind.checklist);
      expect(copy.items.single.done, isTrue);
      expect(copy.tags, note.tags);
      expect(copy.folder, 'F');
      expect(copy.accent, 3);
      expect(copy.pinned, isTrue);
      expect(copy.favorite, isTrue);
      expect(copy.archived, isTrue);
      expect(copy.updatedAt, note.updatedAt);
    });

    test('copyWith can clear the folder', () {
      final Note note = Note(
        id: 'id',
        title: '',
        body: 'x',
        kind: NoteKind.text,
        folder: 'Work',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(note.copyWith(folder: null).folder, isNull);
      expect(note.copyWith(title: 'kept').folder, 'Work');
    });
  });

  group('markdown', () {
    test('stripMarkdown cleans syntax for previews', () {
      expect(stripMarkdown('# Title'), 'Title');
      expect(stripMarkdown('**bold** and *italic*'), 'bold and italic');
      expect(stripMarkdown('`code`'), 'code');
      expect(stripMarkdown('~~gone~~'), 'gone');
      expect(stripMarkdown('- item'), '• item');
      expect(stripMarkdown('- [ ] task'), 'task');
      expect(stripMarkdown('> quoted'), 'quoted');
    });

    test('wrapSelection wraps and then unwraps', () {
      final TextEditingController c = TextEditingController(text: 'hello');
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 5);

      c.wrapSelection('**');
      expect(c.text, '**hello**');

      c.wrapSelection('**');
      expect(c.text, 'hello');
    });

    test('toggleLinePrefix adds, swaps and removes block markers', () {
      final TextEditingController c = TextEditingController(text: 'task');
      c.selection = const TextSelection.collapsed(offset: 4);

      c.toggleLinePrefix('- ');
      expect(c.text, '- task');

      // Swaps one block marker for another rather than stacking them.
      c.toggleLinePrefix('# ');
      expect(c.text, '# task');

      c.toggleLinePrefix('# ');
      expect(c.text, 'task');
    });

    test('editing controller spans cover the text exactly once', () {
      final MarkdownEditingController c = MarkdownEditingController(
        text: '# Head\n**bold** tail\n- [x] done',
      );

      final TextSpan span = c.buildTextSpan(
        context: _FakeContext(),
        style: const TextStyle(fontSize: 16),
        withComposing: false,
      );

      expect(span.toPlainText(), c.text);
    });
  });

  group('app', () {
    // The aurora background animates forever, so `pumpAndSettle` would never
    // return — advance a fixed number of frames instead.
    Future<void> boot(WidgetTester tester) async {
      await tester.pumpWidget(NotedApp(store: MemoryNoteStore()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('boots to the note list', (WidgetTester tester) async {
      await boot(tester);

      expect(find.text('Noted'), findsOneWidget);
      expect(find.text('Welcome to Noted'), findsOneWidget);
    });

    testWidgets('opens a note in the editor', (WidgetTester tester) async {
      await boot(tester);

      await tester.tap(find.text('Welcome to Noted'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(TextField), findsWidgets);
      expect(find.textContaining('Edited'), findsOneWidget);
    });

    testWidgets('search filters the list', (WidgetTester tester) async {
      await boot(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search notes, tags, tasks…').first,
        'groceries',
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Welcome to Noted'), findsNothing);
    });
  });
}

/// Minimal BuildContext stand-in — [MarkdownEditingController.buildTextSpan]
/// never touches it.
class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
