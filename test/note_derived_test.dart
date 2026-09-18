import 'package:flutter_test/flutter_test.dart';
import 'package:noted/models/note.dart';
import 'package:noted/utils/markdown_text.dart';

Note _text(
  String body, {
  String title = '',
  List<String> tags = const <String>[],
}) => Note(
  id: 'n',
  title: title,
  body: body,
  kind: NoteKind.text,
  tags: tags,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('Note.plainPreview', () {
    test('strips markdown and is computed once', () {
      final Note note = _text('# Heading\n\n**bold** and `code`');

      final String first = note.plainPreview;
      expect(first, 'Heading\n\nbold and code');
      // Same String instance, not a re-run of the eight regex passes.
      expect(identical(note.plainPreview, first), isTrue);
    });

    test('matches stripMarkdown on the raw preview', () {
      final Note note = _text('- one\n- two\n\n> quoted ~~out~~');

      expect(note.plainPreview, stripMarkdown(note.preview));
    });

    test('a checklist previews its items', () {
      final Note note = Note(
        id: 'c',
        title: 'Shopping',
        body: '',
        kind: NoteKind.checklist,
        items: const <ChecklistItem>[
          ChecklistItem(id: '1', text: 'rice'),
          ChecklistItem(id: '2', text: '   '),
          ChecklistItem(id: '3', text: 'mango'),
        ],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(note.preview, 'rice  •  mango');
      expect(note.plainPreview, 'rice  •  mango');
    });

    test('copyWith produces a note with its own, correct cache', () {
      final Note note = _text('**first**');
      expect(note.plainPreview, 'first');

      final Note edited = note.copyWith(body: '**second**');

      expect(edited.plainPreview, 'second');
      // The original is untouched.
      expect(note.plainPreview, 'first');
    });

    test('an empty body previews as empty', () {
      expect(_text('').plainPreview, isEmpty);
    });
  });

  group('Note.matches', () {
    test('finds text in the title, body and tags', () {
      final Note note = _text(
        'ship the beta',
        title: 'Roadmap',
        tags: <String>['Planning'],
      );

      expect(note.matches('roadmap'), isTrue);
      expect(note.matches('beta'), isTrue);
      expect(note.matches('planning'), isTrue);
      expect(note.matches('nothing-here'), isFalse);
    });

    test('finds text in checklist items', () {
      final Note note = Note(
        id: 'c',
        title: 'Errands',
        body: '',
        kind: NoteKind.checklist,
        items: const <ChecklistItem>[
          ChecklistItem(id: '1', text: 'buy tamarind'),
        ],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(note.matches('tamarind'), isTrue);
    });

    test('an empty query matches everything', () {
      expect(_text('anything').matches(''), isTrue);
    });

    test('the query is expected pre-lowercased', () {
      final Note note = _text('', title: 'Angkor');

      expect(note.matches('angkor'), isTrue);
      // Callers lower-case once; an upper-case query is not folded for them.
      expect(note.matches('ANGKOR'), isFalse);
    });
  });

  group('newId', () {
    test('ids are unique across a tight loop', () {
      final Set<String> ids = <String>{for (int i = 0; i < 5000; i++) newId()};

      expect(ids, hasLength(5000));
    });
  });
}
