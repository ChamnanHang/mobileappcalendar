import 'dart:async';

import 'package:flutter/material.dart';

import '../data/morning_digest.dart';
import '../data/reminders.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'sheets.dart';
import 'surface.dart';

/// Settings for the morning reminder: on/off, the time, and a preview of what
/// tomorrow's notification will say.
class ReminderSheet extends StatefulWidget {
  const ReminderSheet({super.key, required this.reminders});

  final MorningReminders reminders;

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  /// Set when turning the reminder on did not work, cleared on the next try.
  String? _problem;

  /// Null until known. False only on Android 14+ without exact alarms.
  bool? _exact;

  bool _busy = false;

  AppLifecycleListener? _lifecycle;

  MorningReminders get _reminders => widget.reminders;

  @override
  void initState() {
    super.initState();
    unawaited(_checkExact());
    // Allowing exact alarms happens in system Settings; re-check on the way
    // back, and move the pending reminders onto exact timing if it changed.
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _onResume() async {
    final bool? before = _exact;
    await _checkExact();
    if (before == false && _exact == true) await _reminders.reschedule();
  }

  Future<void> _checkExact() async {
    final bool exact = await _reminders.exactTimingAllowed();
    if (mounted) setState(() => _exact = exact);
  }

  Future<void> _toggle(bool on) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final EnableResult result;
    try {
      result = await _reminders.setEnabled(on);
    } on Object catch (error) {
      debugPrint('Could not change the reminder: $error');
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = 'Could not change the reminder. Try again.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = switch (result) {
        EnableResult.enabled => null,
        EnableResult.permissionDenied =>
          'Notifications are turned off for Noted. Allow them in your '
              "phone's Settings, then try again.",
        EnableResult.unsupported =>
          'Reminders are not available on this device.',
      };
    });
  }

  Future<void> _pickTime() async {
    final ReminderSettings settings = _reminders.settings;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
      helpText: 'Remind me at',
    );
    if (picked == null) return;
    await _reminders.setTime(picked.hour, picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: _reminders,
      builder: (BuildContext context, Widget? _) {
        final ReminderSettings settings = _reminders.settings;
        final String time = TimeOfDay(
          hour: settings.hour,
          minute: settings.minute,
        ).format(context);
        final MorningDigest preview = _reminders.previewTomorrow();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SheetHandle(),
            Text('Morning reminder', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              "A notification each morning with today's Khmer date and any "
              'holy days or holidays today and tomorrow.',
              style: text.bodySmall?.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: 10),
            MergeSemantics(
              // Same inset as the SheetTile below, so the icons line up.
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 20,
                      color: p.textSecondary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Remind me every morning',
                        style: text.bodyLarge,
                      ),
                    ),
                    Switch(
                      value: settings.enabled,
                      onChanged: _busy ? null : _toggle,
                      activeTrackColor: p.accent,
                      activeThumbColor: p.onAccent,
                    ),
                  ],
                ),
              ),
            ),
            SheetTile(
              icon: Icons.schedule_rounded,
              label: 'Time',
              trailing: time,
              onTap: _pickTime,
            ),
            if (_problem != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                _problem!,
                style: text.bodySmall?.copyWith(color: p.holiday),
              ),
            ],
            if (settings.enabled && _exact == false) ...<Widget>[
              const SizedBox(height: 6),
              _ExactTimingHint(onAllow: _reminders.requestExactTiming),
            ],
            const SizedBox(height: 16),
            Text(
              'TOMORROW MORNING',
              style: text.labelSmall?.copyWith(
                color: p.textTertiary,
                letterSpacing: 1.2,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 8),
            SurfaceCard(
              color: p.surfaceMuted,
              borderColor: Colors.transparent,
              radius: AppTheme.radiusMd,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: p.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Noted · $time',
                        style: text.labelSmall?.copyWith(color: p.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(preview.title, style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    preview.body,
                    style: text.bodySmall?.copyWith(
                      color: p.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExactTimingHint extends StatelessWidget {
  const _ExactTimingHint({required this.onAllow});

  final Future<void> Function() onAllow;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Android may deliver it up to an hour late.',
            style: text.bodySmall?.copyWith(color: p.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => unawaited(onAllow()),
          style: TextButton.styleFrom(foregroundColor: p.accent),
          child: const Text('Allow exact time'),
        ),
      ],
    );
  }
}
