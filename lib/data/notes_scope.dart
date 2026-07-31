import 'package:flutter/widgets.dart';

import 'notes_controller.dart';

/// Exposes the [NotesController] to the widget tree and rebuilds dependents
/// whenever it notifies.
class NotesScope extends InheritedNotifier<NotesController> {
  const NotesScope({
    super.key,
    required NotesController controller,
    required super.child,
  }) : super(notifier: controller);

  static NotesController of(BuildContext context) {
    final NotesScope? scope =
        context.dependOnInheritedWidgetOfExactType<NotesScope>();
    assert(scope != null, 'No NotesScope found in the widget tree.');
    return scope!.notifier!;
  }

  /// Reads the controller without subscribing to changes — for callbacks.
  static NotesController read(BuildContext context) {
    final NotesScope? scope =
        context.getInheritedWidgetOfExactType<NotesScope>();
    assert(scope != null, 'No NotesScope found in the widget tree.');
    return scope!.notifier!;
  }
}
