import 'package:flutter/material.dart';

import 'data/note_store.dart';
import 'data/notes_controller.dart';
import 'data/notes_scope.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';

class NotedApp extends StatefulWidget {
  const NotedApp({super.key, this.store});

  /// Injectable persistence — tests pass a [MemoryNoteStore].
  final NoteStore? store;

  @override
  State<NotedApp> createState() => _NotedAppState();
}

class _NotedAppState extends State<NotedApp> {
  late final NotesController _notes = NotesController(store: widget.store);

  @override
  void initState() {
    super.initState();
    _notes.init();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotesScope(
      controller: _notes,
      child: MaterialApp(
        title: 'Noted',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const AppShell(),
      ),
    );
  }
}
