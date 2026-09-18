import 'package:flutter_test/flutter_test.dart';
import 'package:noted/data/note_store.dart';
import 'package:noted/data/notes_controller.dart';
import 'package:noted/models/note.dart';

Note _note({
  required String id,
  String title = '',
  String body = '',
  List<String> tags = const <String>[],
  String? folder,
  bool archived = false,
  bool favorite = false,
  bool pinned = false,
  NoteKind kind = NoteKind.text,
  List<ChecklistItem> items = const <ChecklistItem>[],
  DateTime? updatedAt,
}) {
  final DateTime when = updatedAt ?? DateTime(2026);
  return Note(
    id: id,
    title: title,
    body: body,
    kind: kind,
    items: items,
    tags: tags,
    folder: folder,
    archived: archived,
    favorite: favorite,
    pinned: pinned,
    createdAt: when,
    updatedAt: when,
  );
}

void main() {
  group('derived state is cached but never stale', () {
    test('repeated reads return the identical list', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();

      expect(identical(c.visibleNotes, c.visibleNotes), isTrue);
      expect(identical(c.allTags, c.allTags), isTrue);
      expect(identical(c.allFolders, c.allFolders), isTrue);
      expect(identical(c.activeNotes, c.activeNotes), isTrue);
    });

    test('a mutation invalidates the cached projections', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      final List<Note> before = c.visibleNotes;

      c.upsert(_note(id: 'fresh', title: 'Fresh', tags: <String>['brand-new']));

      expect(identical(c.visibleNotes, before), isFalse);
      expect(c.visibleNotes.map((Note n) => n.id), contains('fresh'));
      expect(c.allTags, contains('brand-new'));
    });

    test('listeners see fresh data, not the pre-mutation cache', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      // Prime every cache before mutating.
      c.visibleNotes;
      c.allTags;
      c.allFolders;

      int? countSeenByListener;
      c.addListener(() => countSeenByListener = c.visibleNotes.length);

      final int before = c.visibleNotes.length;
      c.upsert(_note(id: 'later', title: 'Later'));

      expect(countSeenByListener, before + 1);
    });

    test('changing a filter does not invalidate note-derived caches', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      final List<String> tags = c.allTags;

      c.setFilter(NoteFilter.favorites);

      // The filter changes which notes are visible, not which tags exist.
      expect(identical(c.allTags, tags), isTrue);
      expect(c.visibleNotes.every((Note n) => n.favorite), isTrue);
    });

    test('folder counts ignore archived notes and match the list', () async {
      final NotesController c = NotesController(
        store: MemoryNoteStore(<Note>[
          _note(id: 'a', title: 'A', folder: 'Work'),
          _note(id: 'b', title: 'B', folder: 'Work'),
          _note(id: 'c', title: 'C', folder: 'Work', archived: true),
          _note(id: 'd', title: 'D', folder: 'Home'),
        ]),
      );
      await c.init();

      expect(c.allFolders, <String>['Home', 'Work']);
      expect(c.notesInFolder('Work'), 2);
      expect(c.notesInFolder('Home'), 1);
      expect(c.notesInFolder('Nowhere'), 0);
    });

    test('byId finds notes and forgets deleted ones', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      c.upsert(_note(id: 'target', title: 'Target'));

      expect(c.byId('target')?.title, 'Target');

      c.delete('target');
      expect(c.byId('target'), isNull);
    });
  });

  group('search', () {
    test('search() applies immediately', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      c.upsert(_note(id: 'x', title: 'Roadmap', body: 'ship the beta'));

      c.search('beta');
      expect(c.visibleNotes.single.id, 'x');
    });

    test('searchAsYouType defers the query, then applies it', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      c.upsert(_note(id: 'x', title: 'Roadmap', body: 'ship the beta'));
      final int total = c.visibleNotes.length;

      c.searchAsYouType('beta');

      // Still unfiltered: the debounce has not elapsed.
      expect(c.query, isEmpty);
      expect(c.searchPending, isTrue);
      expect(c.visibleNotes.length, total);

      await Future<void>.delayed(
        NotesController.searchDebounce + const Duration(milliseconds: 40),
      );

      expect(c.query, 'beta');
      expect(c.searchPending, isFalse);
      expect(c.visibleNotes.single.id, 'x');
    });

    test('an empty query applies without waiting', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      c.search('beta');

      c.searchAsYouType('');

      expect(c.query, isEmpty);
      expect(c.searchPending, isFalse);
    });

    test('commitSearch applies a pending query at once', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      c.upsert(_note(id: 'x', title: 'Roadmap'));

      c.searchAsYouType('roadmap');
      c.commitSearch();

      expect(c.query, 'roadmap');
      expect(c.visibleNotes.single.id, 'x');
    });

    test('searchAsYouType matches checklist item text', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();
      c.upsert(
        _note(
          id: 'list',
          title: 'Errands',
          kind: NoteKind.checklist,
          items: <ChecklistItem>[
            const ChecklistItem(id: 'i1', text: 'buy tamarind'),
          ],
        ),
      );

      c.search('tamarind');
      expect(c.visibleNotes.single.id, 'list');
    });

    test('search is case-insensitive across every field', () async {
      final NotesController c = NotesController(
        store: MemoryNoteStore(<Note>[
          _note(id: 'a', title: 'Angkor Trip', tags: <String>['TRAVEL']),
        ]),
      );
      await c.init();

      c.search('angkor');
      expect(c.visibleNotes.single.id, 'a');

      c.search('travel');
      expect(c.visibleNotes.single.id, 'a');
    });

    test('clearFilters resets a pending debounced query too', () async {
      final NotesController c = NotesController(store: MemoryNoteStore());
      await c.init();

      c.searchAsYouType('anything');
      c.clearFilters();

      expect(c.query, isEmpty);
      expect(c.searchPending, isFalse);
    });
  });

  group('save durability', () {
    test(
      'an edit schedules a write rather than writing per keystroke',
      () async {
        final MemoryNoteStore store = MemoryNoteStore();
        final NotesController c = NotesController(store: store);
        await c.init();
        final int baseline = store.saveCount;

        c.upsert(_note(id: 'a', title: 'A'));
        c.upsert(_note(id: 'b', title: 'B'));

        expect(store.saveCount, baseline, reason: 'writes are debounced');
        expect(c.hasPendingSave, isTrue);
      },
    );

    test('flush writes the pending edit immediately', () async {
      final MemoryNoteStore store = MemoryNoteStore();
      final NotesController c = NotesController(store: store);
      await c.init();

      c.upsert(_note(id: 'a', title: 'A'));
      await c.flush();

      expect(c.hasPendingSave, isFalse);
      expect((await store.load()).map((Note n) => n.id), contains('a'));
    });

    test('flushIfPending is a no-op when nothing is pending', () async {
      final MemoryNoteStore store = MemoryNoteStore();
      final NotesController c = NotesController(store: store);
      await c.init();
      await c.flush();
      final int after = store.saveCount;

      await c.flushIfPending();

      expect(store.saveCount, after);
    });

    test('dispose writes a pending edit instead of dropping it', () async {
      final MemoryNoteStore store = MemoryNoteStore();
      final NotesController c = NotesController(store: store);
      await c.init();

      c.upsert(_note(id: 'unsaved', title: 'Unsaved'));
      c.dispose();
      // Let the write that dispose kicked off settle.
      await Future<void>.delayed(Duration.zero);

      expect(
        (await store.load()).map((Note n) => n.id),
        contains('unsaved'),
        reason: 'dispose used to cancel the debounce without writing',
      );
    });
  });
}
