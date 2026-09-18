import 'dart:async';

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
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    unawaited(_notes.init());

    // Edits are written on a short debounce. Both platforms may kill a
    // backgrounded process without another callback, so anything still pending
    // when the app leaves the foreground has to go to disk now.
    _lifecycle = AppLifecycleListener(
      onInactive: _flush,
      onPause: _flush,
      onDetach: _flush,
      onHide: _flush,
    );
  }

  void _flush() => unawaited(_notes.flushIfPending());

  @override
  void dispose() {
    _lifecycle?.dispose();
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
        // The app is dark-only by design; say so explicitly rather than
        // letting the platform pick, which would otherwise flash a light
        // Material surface on a light-mode device.
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const AppShell(),
        builder: (BuildContext context, Widget? child) {
          // Very large system font settings otherwise overflow the compact
          // chrome (nav bar, chips, calendar cells). Clamping keeps the app
          // legible and usable at accessibility sizes without breaking layout.
          final MediaQueryData media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.35,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
