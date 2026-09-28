import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Monochrome on purpose: an empty screen should not compete for
          // attention with the button that fills it.
          Icon(icon, size: 36, color: p.textTertiary),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: p.textTertiary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
