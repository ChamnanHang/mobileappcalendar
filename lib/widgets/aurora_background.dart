import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Slow-drifting neon "aurora" blobs behind the whole app. Pure gradients —
/// no blur filters — so it stays cheap on mobile and web.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppColors.bgAlt, AppColors.bg],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? _) {
                  return CustomPaint(
                    painter: _AuroraPainter(_controller.value),
                  );
                },
              ),
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t);

  final double t;

  static const List<_Blob> _blobs = <_Blob>[
    _Blob(AppColors.violet, 0.20, 0.16, 0.62, 0.30),
    _Blob(AppColors.cyan, 0.86, 0.30, 0.52, 0.22),
    _Blob(AppColors.pink, 0.62, 0.86, 0.58, 0.20),
    _Blob(AppColors.blue, 0.08, 0.74, 0.46, 0.18),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double tau = t * 2 * math.pi;

    for (int i = 0; i < _blobs.length; i++) {
      final _Blob blob = _blobs[i];
      final double phase = tau + i * math.pi / 2;

      final Offset center = Offset(
        (blob.x + 0.05 * math.cos(phase)) * size.width,
        (blob.y + 0.045 * math.sin(phase * 0.8)) * size.height,
      );
      final double radius =
          blob.radius * size.shortestSide * (1 + 0.06 * math.sin(phase));

      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            blob.color.withValues(alpha: blob.opacity),
            blob.color.withValues(alpha: 0),
          ],
          stops: const <double>[0, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => oldDelegate.t != t;
}

class _Blob {
  const _Blob(this.color, this.x, this.y, this.radius, this.opacity);

  final Color color;
  final double x;
  final double y;
  final double radius;
  final double opacity;
}
