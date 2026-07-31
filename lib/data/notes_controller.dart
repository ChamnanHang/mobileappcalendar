import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/note.dart';
import 'note_store.dart';

enum NoteFilter { all, favorites, archive }

/// Single source of truth for notes, search and filters.
class NotesController extends ChangeNotifier {
  NotesController({NoteStore? store}) : _store = store ?? PrefsNoteStore();

  final NoteStore _store;
  final List<Note> _notes = <Note>[];

  bool _loading = true;
  String _query = '';
  String? _activeTag;
  String? _activeFolder;
  NoteFilter _filter = NoteFilter.all;
  Timer? _saveDebounce;

  bool get loading => _loading;
  String get query => _query;
  String? get activeTag => _activeTag;
  String? get activeFolder => _activeFolder;
  NoteFilter get filter => _filter;

  bool get hasAnyNote => _notes.any((Note n) => !n.archived);
  int get archivedCount => _notes.where((Note n) => n.archived).length;
  int get favoriteCount =>
      _notes.where((Note n) => n.favorite && !n.archived).length;

  Future<void> init() async {
    final List<Note> loaded = await _store.load();
    _notes
      ..clear()
      ..addAll(loaded);
    if (_notes.isEmpty) _notes.addAll(_seedNotes());
    _loading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------- queries

  /// Every tag in use, most-used first.
  List<String> get allTags {
    final Map<String, int> counts = <String, int>{};
    for (final Note note in _notes) {
      if (note.archived) continue;
      for (final String tag in note.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final List<String> tags = counts.keys.toList()
      ..sort((String a, String b) {
        final int byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.toLowerCase().compareTo(b.toLowerCase());
      });
    return tags;
  }

  /// Folders in use, alphabetical.
  List<String> get allFolders {
    final Set<String> folders = <String>{};
    for (final Note note in _notes) {
      final String? folder = note.folder;
      if (folder != null && folder.trim().isNotEmpty) folders.add(folder);
    }
    final List<String> list = folders.toList()
      ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  int notesInFolder(String folder) => _notes
      .where((Note n) => !n.archived && n.folder == folder)
      .length;

  /// Filtered + sorted notes for the current view. Pinned float to the top.
  List<Note> get visibleNotes {
    final String q = _query.trim().toLowerCase();

    final List<Note> result = _notes.where((Note note) {
      switch (_filter) {
        case NoteFilter.archive:
          if (!note.archived) return false;
        case NoteFilter.favorites:
          if (note.archived || !note.favorite) return false;
        case NoteFilter.all:
          if (note.archived) return false;
      }

      if (_activeTag != null && !note.tags.contains(_activeTag)) return false;
      if (_activeFolder != null && note.folder != _activeFolder) return false;

      if (q.isEmpty) return true;
      return note.title.toLowerCase().contains(q) ||
          note.body.toLowerCase().contains(q) ||
          note.tags.any((String t) => t.toLowerCase().contains(q)) ||
          note.items.any((ChecklistItem i) => i.text.toLowerCase().contains(q));
    }).toList();

    result.sort((Note a, Note b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return result;
  }

  /// Every non-archived note, unaffected by the current view filters.
  /// Used by the calendar to mark days that already have notes.
  List<Note> get activeNotes =>
      _notes.where((Note n) => !n.archived).toList(growable: false);

  Note? byId(String id) {
    for (final Note note in _notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  // ---------------------------------------------------------------- filters

  void search(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void setFilter(NoteFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  void toggleTagFilter(String? tag) {
    _activeTag = _activeTag == tag ? null : tag;
    notifyListeners();
  }

  void selectFolder(String? folder) {
    _activeFolder = _activeFolder == folder ? null : folder;
    notifyListeners();
  }

  void clearFilters() {
    _query = '';
    _activeTag = null;
    _activeFolder = null;
    _filter = NoteFilter.all;
    notifyListeners();
  }

  // ---------------------------------------------------------------- mutation

  /// Creates a draft that is only persisted once it has content.
  Note draft({NoteKind kind = NoteKind.text}) => Note.empty(
        kind: kind,
        folder: _activeFolder,
        accent: _notes.length % 6,
      );

  /// Inserts or updates a note. Empty notes are dropped instead of saved.
  void upsert(Note note) {
    final int index = _notes.indexWhere((Note n) => n.id == note.id);

    if (note.isEmpty) {
      if (index != -1) {
        _notes.removeAt(index);
        _scheduleSave();
        notifyListeners();
      }
      return;
    }

    if (index == -1) {
      _notes.add(note);
    } else {
      _notes[index] = note;
    }
    _scheduleSave();
    notifyListeners();
  }

  void delete(String id) {
    _notes.removeWhere((Note n) => n.id == id);
    _scheduleSave();
    notifyListeners();
  }

  /// Re-inserts a deleted note (undo support).
  void restore(Note note) {
    _notes.add(note);
    _scheduleSave();
    notifyListeners();
  }

  void togglePin(String id) => _mutate(
        id,
        (Note n) => n.copyWith(pinned: !n.pinned),
      );

  void toggleFavorite(String id) => _mutate(
        id,
        (Note n) => n.copyWith(favorite: !n.favorite),
      );

  void setArchived(String id, bool archived) => _mutate(
        id,
        (Note n) => n.copyWith(archived: archived, pinned: false),
      );

  void setAccent(String id, int accent) =>
      _mutate(id, (Note n) => n.copyWith(accent: accent));

  void setFolderOf(String id, String? folder) =>
      _mutate(id, (Note n) => n.copyWith(folder: folder));

  void toggleChecklistItem(String noteId, String itemId) => _mutate(
        noteId,
        (Note note) => note.copyWith(
          items: note.items
              .map((ChecklistItem i) =>
                  i.id == itemId ? i.copyWith(done: !i.done) : i)
              .toList(),
        ),
      );

  void _mutate(String id, Note Function(Note) transform) {
    final int index = _notes.indexWhere((Note n) => n.id == id);
    if (index == -1) return;
    _notes[index] = transform(_notes[index]);
    _scheduleSave();
    notifyListeners();
  }

  // ---------------------------------------------------------------- saving

  /// Coalesces bursts of edits into one write.
  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _store.save(_notes),
    );
  }

  Future<void> flush() async {
    _saveDebounce?.cancel();
    await _store.save(_notes);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- seed

  /// A few notes on first launch so the app never opens empty.
  List<Note> _seedNotes() {
    final DateTime now = DateTime.now();
    return <Note>[
      Note(
        id: newId(),
        title: 'Welcome to Noted',
        body: 'A calm place for the things you want to keep.\n\n'
            '**Bold**, *italic* and `code` work inline.\n\n'
            '# Big heading\n'
            '## Smaller heading\n\n'
            '- Swipe a card to archive it\n'
            '- Long-press a card for quick actions\n'
            '- Tap the star to favourite\n\n'
            '> Everything is saved on this device.',
        kind: NoteKind.text,
        tags: <String>['welcome'],
        folder: 'Personal',
        accent: 0,
        pinned: true,
        createdAt: now,
        updatedAt: now,
      ),
      Note(
        id: newId(),
        title: 'Groceries',
        body: '',
        kind: NoteKind.checklist,
        items: <ChecklistItem>[
          ChecklistItem(id: newId(), text: 'Coffee beans', done: true),
          ChecklistItem(id: newId(), text: 'Oat milk'),
          ChecklistItem(id: newId(), text: 'Mangoes'),
          ChecklistItem(id: newId(), text: 'Rice'),
        ],
        tags: <String>['shopping'],
        folder: 'Personal',
        accent: 3,
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedAt: now.subtract(const Duration(hours: 5)),
      ),
      Note(
        id: newId(),
        title: 'App ideas',
        body: 'Things worth building next:\n\n'
            '- Offline-first habit tracker\n'
            '- Khmer/English dictionary with handwriting input\n'
            '- A tiny expense splitter for trips',
        kind: NoteKind.text,
        tags: <String>['ideas', 'work'],
        folder: 'Work',
        accent: 1,
        favorite: true,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}
