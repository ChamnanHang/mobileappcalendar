import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ads.dart';
import '../screens/calendar_screen.dart';
import '../screens/home_screen.dart';
import '../theme/app_colors.dart';
import 'aurora_background.dart';
import 'glass.dart';

/// Hosts the two top-level surfaces and owns the single aurora background, so
/// switching tabs never restarts the animation.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  /// The calendar is only built once its tab has been opened, so the app never
  /// calls the calendar service at startup.
  bool _calendarVisited = false;

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _index,
          children: <Widget>[
            const HomeScreen(),
            if (_calendarVisited)
              const CalendarScreen()
            else
              const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Renders nothing unless ads are enabled on a mobile build.
            const AdBanner(),
            _GlassNavBar(
              index: _index,
              onChanged: (int value) {
                if (value == _index) return;
                HapticFeedback.selectionClick();
                setState(() {
                  _index = value;
                  if (value == 1) _calendarVisited = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        12 + MediaQuery.paddingOf(context).bottom * 0.4,
      ),
      child: GlassPanel(
        radius: 22,
        blur: 26,
        fill: AppColors.glassFillStrong,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _NavItem(
                icon: Icons.sticky_note_2_rounded,
                label: 'Notes',
                accent: AppColors.violet,
                selected: index == 0,
                onTap: () => onChanged(0),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Calendar',
                accent: AppColors.cyan,
                selected: index == 1,
                onTap: () => onChanged(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.42)
                : Colors.transparent,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 19, color: selected ? accent : AppColors.textLow),
            const SizedBox(width: 8),
            // Flexible so the bar survives very narrow layouts instead of
            // overflowing.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 13.5,
                  color: selected ? AppColors.textHigh : AppColors.textLow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
