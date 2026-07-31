import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A frosted-glass panel: blurred backdrop, translucent fill, hairline border
/// and a soft top-left sheen.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppTheme.radiusMd,
    this.blur = 18,
    this.fill,
    this.borderColor,
    this.glow,
    this.glowOpacity = 0.22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? fill;
  final Color? borderColor;

  /// Optional neon colour bloomed behind the panel.
  final Color? glow;
  final double glowOpacity;

  @override
  Widget build(BuildContext context) {
    final BorderRadius shape = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: <BoxShadow>[
          if (glow != null)
            BoxShadow(
              color: glow!.withValues(alpha: glowOpacity),
              blurRadius: 34,
              spreadRadius: -6,
              offset: const Offset(0, 10),
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  (fill ?? AppColors.glassFill).withValues(
                    alpha: ((fill ?? AppColors.glassFill).a + 0.05).clamp(0.0, 1.0),
                  ),
                  fill ?? AppColors.glassFill,
                ],
              ),
              border: Border.all(
                color: borderColor ?? AppColors.glassBorder,
                width: 1,
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Glass panel that reacts to touch with a subtle scale + brighten.
class GlassTapPanel extends StatefulWidget {
  const GlassTapPanel({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppTheme.radiusMd,
    this.glow,
    this.blur = 18,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glow;
  final double blur;

  @override
  State<GlassTapPanel> createState() => _GlassTapPanelState();
}

class _GlassTapPanelState extends State<GlassTapPanel> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.975 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: GlassPanel(
          padding: widget.padding,
          radius: widget.radius,
          blur: widget.blur,
          glow: widget.glow,
          glowOpacity: _down ? 0.34 : 0.18,
          fill: _down ? AppColors.glassFillStrong : AppColors.glassFill,
          borderColor:
              _down ? AppColors.glassBorderStrong : AppColors.glassBorder,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Small circular glass icon button used in app bars and toolbars.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.active = false,
    this.activeColor,
    this.size = 42,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool active;
  final Color? activeColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color accent = activeColor ?? AppColors.cyan;
    final Widget button = GlassTapPanel(
      onTap: onTap,
      radius: size / 2,
      blur: 12,
      padding: EdgeInsets.zero,
      glow: active ? accent : null,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: active ? accent : AppColors.textMid),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            builder: (BuildContext context, Color? value, Widget? _) => Icon(
              icon,
              size: 20,
              color: value ?? AppColors.textMid,
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
