import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/note.dart';
import 'note_store.dart';

enum NoteFilter { all, favorites, archive }

/// Single source of truth for notes, search and filters.
///
/// Every derived list ([visibleNotes], [allTags], …) is computed once per
/// mutation and cached. Widgets read these getters from `build`, which runs
/// far more often than the data changes, so recomputing a filter-and-sort on
/// each read showed up as jank once a few hundred notes were on screen.
class NotesController extends ChangeNotifier {
  NotesController({NoteStore? store}) : _store = store ?? PrefsNoteStore();

  /// How long to coalesce edits before writing to disk.
  static const Duration saveDebounce = Duration(milliseconds: 350);

  /// How long to wait after the last keystroke before re-running a search.
  static const Duration searchDebounce = Duration(milliseconds: 180);

  final NoteStore _store;
  final List<Note> _notes = <Note>[];

  bool _loading = true;
  String _query = '';
  String _pendingQuery = '';
  String? _activeTag;
  String? _activeFolder;
  NoteFilter _filter = NoteFilter.all;
  Timer? _saveDebounce;
  Timer? _searchDebounce;
  bool _disposed = false;

  bool get loading => _loading;

  /// The query currently applied to [visibleNotes]. Lags the text field by up
  /// to [searchDebounce] while the user is typing.
  String get query => _query;
  String? get activeTag => _activeTag;
  String? get activeFolder => _activeFolder;
  NoteFilter get filter => _filter;

  /// True while a typed query has not yet been applied.
  bool get searchPending => _pendingQuery != _query;

  // ------------------------------------------------------------ derived cache

  List<Note>? _visibleCache;
  List<String>? _tagsCache;
  List<String>? _foldersCache;
  Map<String, int>? _folderCountsCache;
  List<Note>? _activeCache;
  Map<String, Note>? _byIdCache;
  int? _archivedCountCache;
  int? _favoriteCountCache;

  /// Drops every memoized projection. Called whenever notes or filters change.
  void _invalidate({bool notesChanged = true}) {
    _visibleCache = null;
    if (notesChanged) {
      _tagsCache = null;
      _foldersCache = null;
      _folderCountsCache = null;
      _activeCache = null;
      _byIdCache = null;
      _archivedCountCache = null;
      _favoriteCountCache = null;
    }
  }

  /// Invalidates, then notifies — the order matters, or listeners rebuild
  /// against stale caches.
  void _changed({bool notesChanged = true}) {
    _invalidate(notesChanged: notesChanged);
    notifyListeners();
  }

  Future<void> init() async {
    final List<Note> loaded = await _store.load();
    if (_disposed) return;
    _notes
      ..clear()
      ..addAll(loaded);
    if (_notes.isEmpty) _notes.addAll(_seedNotes());
    _loading = false;
    _changed();
  }

  // ---------------------------------------------------------------- queries

  bool get hasAnyNote => activeNotes.isNotEmpty;

  int get archivedCount =>
      _archivedCountCache ??= _notes.where((Note n) => n.archived).length;

  int get favoriteCount => _favoriteCountCache ??= _notes
      .where((Note n) => n.favorite && !n.archived)
      .length;

  /// Every tag in use, most-used first.
  List<String> get allTags => _tagsCache ??= _computeTags();

  List<String> _computeTags() {
    final Map<String, int> counts = <String, int>{};
    for (final Note note in _notes) {
      if (note.archived) continue;
      for (final String tag in note.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts.keys.toList()..sort((String a, String b) {
      final int byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0
          ? byCount
          : a.toLowerCase().compareTo(b.toLowerCase());
    });
  }

  /// Folders in use, alphabetical.
  List<String> get allFolders {
    _ensureFolders();
    return _foldersCache!;
  }

  /// Folder list and per-folder counts share one pass — the home screen always
  /// needs both.
  void _ensureFolders() {
    if (_foldersCache != null) return;
    final Map<String, int> counts = <String, int>{};
    final Set<String> all = <String>{};
    for (final Note note in _notes) {
      final String? folder = note.folder;
      if (folder == null || folder.trim().isEmpty) continue;
      all.add(folder);
      if (!note.archived) counts[folder] = (counts[folder] ?? 0) + 1;
    }
    _foldersCache = all.toList()
      ..sort(
        (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );
    _folderCountsCache = counts;
  }

  int notesInFolder(String folder) {
    _ensureFolders();
    return _folderCountsCache![folder] ?? 0;
  }

  /// Filtered + sorted notes for the current view. Pinned float to the top.
  List<Note> get visibleNotes => _visibleCache ??= _computeVisible();

  List<Note> _computeVisible() {
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

      return q.isEmpty || note.matches(q);
    }).toList();

    result.sort((Note a, Note b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return List<Note>.unmodifiable(result);
  }

  /// Every non-archived note, unaffected by the current view filters.
  /// Used by the calendar to mark days that already have notes.
  List<Note> get activeNotes => _activeCache ??= List<Note>.unmodifiable(
    _notes.where((Note n) => !n.archived),
  );

  Note? byId(String id) => (_byIdCache ??= <String, Note>{
    for (final Note note in _notes) note.id: note,
  })[id];

  // ---------------------------------------------------------------- filters

  /// Applies [value] immediately.
  void search(String value) {
    _pendingQuery = value;
    _applyQuery(value);
  }

  /// Applies [value] after [searchDebounce] elapses without another keystroke.
  ///
  /// Every applied query re-filters and re-sorts the whole list, so running
  /// that once per character is wasted work on a long list. The text field
  /// itself still updates on every keystroke — only the filtering waits.
  void searchAsYouType(String value) {
    if (_pendingQuery == value) return;
    _pendingQuery = value;

    _searchDebounce?.cancel();
    // Clearing the field should feel instant; only typing is debounced.
    if (value.isEmpty) {
      _applyQuery(value);
      return;
    }
    _searchDebounce = Timer(searchDebounce, () => _applyQuery(value));
  }

  void _applyQuery(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    if (_query == value) return;
    _query = value;
    _changed(notesChanged: false);
  }

  /// Applies any pending query immediately — used when the user submits the
  /// search field rather than waiting out the debounce.
  void commitSearch() => _applyQuery(_pendingQuery);

  void setFilter(NoteFilter value) {
    if (_filter == value) return;
    _filter = value;
    _changed(notesChanged: false);
  }

  void toggleTagFilter(String? tag) {
    _activeTag = _activeTag == tag ? null : tag;
    _changed(notesChanged: false);
  }

  void selectFolder(String? folder) {
    _activeFolder = _activeFolder == folder ? null : folder;
    _changed(notesChanged: false);
  }

  void clearFilters() {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    _query = '';
    _pendingQuery = '';
    _activeTag = null;
    _activeFolder = null;
    _filter = NoteFilter.all;
    _changed(notesChanged: false);
  }

  // ---------------------------------------------------------------- mutation

  /// Creates a draft that is only persisted once it has content.
  Note draft({NoteKind kind = NoteKind.text}) =>
      Note.empty(kind: kind, folder: _activeFolder, accent: _notes.length % 6);

  /// Inserts or updates a note. Empty notes are dropped instead of saved.
  void upsert(Note note) {
    final int index = _notes.indexWhere((Note n) => n.id == note.id);

    if (note.isEmpty) {
      if (index != -1) {
        _notes.removeAt(index);
        _scheduleSave();
        _changed();
      }
      return;
    }

    if (index == -1) {
      _notes.add(note);
    } else {
      if (identical(_notes[index], note)) return;
      _notes[index] = note;
    }
    _scheduleSave();
    _changed();
  }

  void delete(String id) {
    final int before = _notes.length;
    _notes.removeWhere((Note n) => n.id == id);
    if (_notes.length == before) return;
    _scheduleSave();
    _changed();
  }

  /// Re-inserts a deleted note (undo support).
  void restore(Note note) {
    _notes.add(note);
    _scheduleSave();
    _changed();
  }

  void togglePin(String id) =>
      _mutate(id, (Note n) => n.copyWith(pinned: !n.pinned));

  void toggleFavorite(String id) =>
      _mutate(id, (Note n) => n.copyWith(favorite: !n.favorite));

  void setArchived(String id, bool archived) =>
      _mutate(id, (Note n) => n.copyWith(archived: archived, pinned: false));

  void setAccent(String id, int accent) =>
      _mutate(id, (Note n) => n.copyWith(accent: accent));

  void setFolderOf(String id, String? folder) =>
      _mutate(id, (Note n) => n.copyWith(folder: folder));

  void toggleChecklistItem(String noteId, String itemId) => _mutate(
    noteId,
    (Note note) => note.copyWith(
      items: note.items
          .map(
            (ChecklistItem i) => i.id == itemId ? i.copyWith(done: !i.done) : i,
          )
          .toList(),
    ),
  );

  void _mutate(String id, Note Function(Note) transform) {
    final int index = _notes.indexWhere((Note n) => n.id == id);
    if (index == -1) return;
    _notes[index] = transform(_notes[index]);
    _scheduleSave();
    _changed();
  }

  // ---------------------------------------------------------------- saving

  /// Coalesces bursts of edits into one write.
  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(saveDebounce, () {
      _saveDebounce = null;
      unawaited(_store.save(_notes));
    });
  }

  /// True when an edit is waiting to be written to disk.
  @visibleForTesting
  bool get hasPendingSave => _saveDebounce != null;

  /// Writes immediately, cancelling any pending debounce.
  ///
  /// Called when the app leaves the foreground: Android and iOS may kill a
  /// backgrounded process without further warning, and a debounced write that
  /// never ran is a lost note.
  Future<void> flush() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    await _store.save(_notes);
  }

  /// Flushes only if something is actually pending, so routine lifecycle
  /// transitions do not cause redundant disk writes.
  Future<void> flushIfPending() async {
    if (_saveDebounce == null) return;
    await flush();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    // A pending edit must still reach disk — cancelling the timer alone would
    // silently drop it.
    if (_saveDebounce != null) {
      _saveDebounce!.cancel();
      _saveDebounce = null;
      unawaited(_store.save(_notes));
    }
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
        body:
            'A calm place for the things you want to keep.\n\n'
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
        body:
            'Things worth building next:\n\n'
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
