import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/note_store.dart';
import 'data/notes_controller.dart';
import 'data/notes_scope.dart';
import 'data/local_notification_scheduler.dart';
import 'data/reminders.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';

class NotedApp extends StatefulWidget {
  const NotedApp({
    super.key,
    this.store,
    this.reminderScheduler,
    this.reminderSettings,
  });

  /// Injectable persistence — tests pass a [MemoryNoteStore].
  final NoteStore? store;

  /// Injectable reminder plumbing — tests pass fakes. Defaults to real
  /// notifications on Android and iOS, and none elsewhere.
  final ReminderScheduler? reminderScheduler;
  final ReminderSettingsStore? reminderSettings;

  @override
  State<NotedApp> createState() => _NotedAppState();
}

class _NotedAppState extends State<NotedApp> {
  late final NotesController _notes = NotesController(store: widget.store);
  late final MorningReminders _reminders = MorningReminders(
    scheduler: widget.reminderScheduler ?? defaultReminderScheduler(),
    store: widget.reminderSettings,
  );
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    unawaited(_notes.init());
    unawaited(_reminders.init());

    // Edits are written on a short debounce. Both platforms may kill a
    // backgrounded process without another callback, so anything still pending
    // when the app leaves the foreground has to go to disk now.
    _lifecycle = AppLifecycleListener(
      onInactive: _flush,
      onPause: _flush,
      onDetach: _flush,
      onHide: _flush,
      // Reminders are scheduled two months ahead; each return to the app
      // rolls that window forward to start from the next morning.
      onResume: () => unawaited(_reminders.refresh()),
    );
  }

  void _flush() => unawaited(_notes.flushIfPending());

  @override
  void dispose() {
    _lifecycle?.dispose();
    _notes.dispose();
    _reminders.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotesScope(
      controller: _notes,
      child: RemindersScope(
        controller: _reminders,
        child: MaterialApp(
          title: 'Noted',
          debugShowCheckedModeBanner: false,
          // Follows the system light/dark setting. Both launch screens do too,
          // so the first frame matches whatever the OS drew before it.
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          home: const AppShell(),
          builder: (BuildContext context, Widget? child) {
            // Very large system font settings otherwise overflow the compact
            // chrome (nav bar, chips, calendar cells). Clamping keeps the app
            // legible and usable at accessibility sizes without breaking layout.
            final MediaQueryData media = MediaQuery.of(context);
            final bool dark = Theme.of(context).brightness == Brightness.dark;
            // No screen has an AppBar to set the status bar style, so it is set
            // once here, above the navigator, and flips with the theme — dark
            // icons on the light background, light icons on the dark one.
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value:
                  (dark
                          ? SystemUiOverlayStyle.light
                          : SystemUiOverlayStyle.dark)
                      .copyWith(
                        statusBarColor: Colors.transparent,
                        systemNavigationBarColor: Colors.transparent,
                      ),
              child: MediaQuery(
                data: media.copyWith(
                  textScaler: media.textScaler.clamp(
                    minScaleFactor: 0.85,
                    maxScaleFactor: 1.35,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        ),
      ),
    );
  }
}
