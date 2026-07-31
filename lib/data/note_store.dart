import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';

/// Persistence boundary. Swap the implementation (SQLite, Isar, a REST API,
/// Supabase…) without touching the UI layer.
abstract class NoteStore {
  Future<List<Note>> load();
  Future<void> save(List<Note> notes);
}

/// Default local-only store: the whole note list as one JSON blob.
/// Works on Android, iOS, web and desktop with no extra setup.
class PrefsNoteStore implements NoteStore {
  PrefsNoteStore({this.key = 'noted.notes.v1'});

  final String key;

  @override
  Future<List<Note>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <Note>[];

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return <Note>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Note.fromJson)
          .toList();
    } on FormatException {
      // Corrupted payload — start clean rather than crash on launch.
      return <Note>[];
    }
  }

  @override
  Future<void> save(List<Note> notes) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw =
        jsonEncode(notes.map((Note n) => n.toJson()).toList(growable: false));
    await prefs.setString(key, raw);
  }
}

/// In-memory store, handy for tests and previews.
class MemoryNoteStore implements NoteStore {
  MemoryNoteStore([List<Note>? seed]) : _notes = <Note>[...?seed];

  List<Note> _notes;

  @override
  Future<List<Note>> load() async => <Note>[..._notes];

  @override
  Future<void> save(List<Note> notes) async => _notes = <Note>[...notes];
}
