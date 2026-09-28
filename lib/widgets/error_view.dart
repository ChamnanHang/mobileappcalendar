import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shown in place of a widget subtree that threw while building.
///
/// Flutter's default is the red screen in debug and a bare grey box in
/// release. This keeps a failure inside the app's own visual language and,
/// more importantly, tells the user their notes are still on the device —
/// which is true, because the store is untouched by a render failure.
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    // This runs when something has already gone wrong, so it deliberately
    // depends on nothing in the tree: no Theme, no MediaQuery, no inherited
    // state that might itself be what failed. Brightness is read straight from
    // the platform instead, so the message still matches light or dark mode.
    final AppPalette p =
        PlatformDispatcher.instance.platformBrightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;

    return ColoredBox(
      color: p.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.error_outline_rounded, size: 30, color: p.holiday),
              const SizedBox(height: 14),
              Text(
                'Something went wrong here',
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your notes are safe on this device. '
                'Going back and reopening usually clears it.',
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
