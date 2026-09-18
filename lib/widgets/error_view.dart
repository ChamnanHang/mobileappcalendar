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
    // depends on nothing: no Theme lookup, no MediaQuery, no inherited state
    // that might itself be the thing that failed.
    return const ColoredBox(
      color: AppColors.bg,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.error_outline_rounded,
                size: 34,
                color: AppColors.pink,
              ),
              SizedBox(height: 14),
              Text(
                'Something went wrong here',
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHigh,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Your notes are safe on this device. '
                'Going back and reopening usually clears it.',
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Color(0xFF9A9CAD),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
