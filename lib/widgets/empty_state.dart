import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color glow = accent ?? AppColors.violet;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  glow.withValues(alpha: 0.30),
                  glow.withValues(alpha: 0.02),
                ],
              ),
              border: Border.all(color: glow.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, size: 32, color: glow),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: text.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: AppColors.textLow, height: 1.5),
          ),
        ],
      ),
    );
  }
}
