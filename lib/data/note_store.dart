import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    } on Object catch (error, stack) {
      // A corrupted or partially-written payload must never stop the app from
      // launching. `FormatException` is only the common case: a truncated blob
      // can also surface as a cast error out of `Note.fromJson`, so this
      // catches everything and starts clean instead.
      debugPrint('Could not read stored notes, starting empty: $error');
      assert(() {
        debugPrintStack(stackTrace: stack);
        return true;
      }());
      return <Note>[];
    }
  }

  @override
  Future<void> save(List<Note> notes) async {
    // Encode before awaiting anything: the caller may keep mutating the list
    // (a checklist tick while a save is in flight), and a snapshot taken after
    // the await could capture a half-applied edit.
    final String raw = jsonEncode(
      notes.map((Note n) => n.toJson()).toList(growable: false),
    );
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, raw);
    } on Object catch (error) {
      // Losing one write is recoverable; an unhandled async error inside a
      // lifecycle callback is not.
      debugPrint('Could not save notes: $error');
    }
  }
}

/// In-memory store, handy for tests and previews.
class MemoryNoteStore implements NoteStore {
  MemoryNoteStore([List<Note>? seed]) : _notes = <Note>[...?seed];

  List<Note> _notes;

  /// How many times [save] has run — lets tests assert that a flush happened.
  int saveCount = 0;

  @override
  Future<List<Note>> load() async => <Note>[..._notes];

  @override
  Future<void> save(List<Note> notes) async {
    saveCount++;
    _notes = <Note>[...notes];
  }
}
