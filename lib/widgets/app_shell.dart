import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ads.dart';
import '../screens/calendar_screen.dart';
import '../screens/home_screen.dart';
import '../theme/app_colors.dart';

/// Hosts the two top-level tabs: the calendar first, then notes.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Tab indices, so callers and tests do not depend on a bare `0` or `1`.
  static const int calendarTab = 0;
  static const int notesTab = 1;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = AppShell.calendarTab;

  /// Notes are only built once their tab has been opened. The calendar is the
  /// landing screen now, so it is the one built eagerly; the note grid waits
  /// until someone asks for it.
  bool _notesVisited = false;

  void _select(int value) {
    if (value == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _index = value;
      if (value == AppShell.notesTab) _notesVisited = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          const CalendarScreen(),
          if (_notesVisited) const HomeScreen() else const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Renders nothing unless ads are enabled on a mobile build.
          const AdBanner(),
          _NavBar(index: _index, onChanged: _select),
        ],
      ),
    );
  }
}

/// A flat tab bar: a hairline rule on top, icon over label, and the accent on
/// the current tab.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.background,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: <Widget>[
              Expanded(
                child: _NavItem(
                  icon: Icons.calendar_today_outlined,
                  selectedIcon: Icons.calendar_today,
                  label: 'Calendar',
                  selected: index == AppShell.calendarTab,
                  onTap: () => onChanged(AppShell.calendarTab),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.sticky_note_2_outlined,
                  selectedIcon: Icons.sticky_note_2,
                  label: 'Notes',
                  selected: index == AppShell.notesTab,
                  onTap: () => onChanged(AppShell.notesTab),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Color color = selected ? p.accent : p.textTertiary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(selected ? selectedIcon : icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
