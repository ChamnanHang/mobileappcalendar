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
    this.blurred = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? fill;
  final Color? borderColor;

  /// Whether to actually sample and blur the backdrop.
  ///
  /// Each `BackdropFilter` costs a `saveLayer` plus a gaussian pass over the
  /// pixels behind it, and that price is paid per panel, per frame. It is
  /// worth paying for the handful of chrome surfaces that sit over scrolling
  /// content, but not for surfaces that appear dozens at a time: what sits
  /// behind those is the aurora, an already-smooth gradient, and blurring a
  /// smooth gradient returns very nearly the same pixels. Those panels pass
  /// `false` and get the translucent fill, border and sheen without the
  /// per-frame cost.
  final bool blurred;

  /// Optional neon colour bloomed behind the panel.
  final Color? glow;
  final double glowOpacity;

  @override
  Widget build(BuildContext context) {
    final BorderRadius shape = BorderRadius.circular(radius);

    final Color base = fill ?? AppColors.glassFill;
    // Unblurred panels lean a little more opaque so they read as solid glass
    // rather than as a thin wash over the background.
    final Color tint = blurred ? base : base.withValues(alpha: base.a + 0.035);

    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            tint.withValues(alpha: (tint.a + 0.05).clamp(0.0, 1.0)),
            tint,
          ],
        ),
        border: Border.all(
          color: borderColor ?? AppColors.glassBorder,
          width: 1,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

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
        child: blurred
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: surface,
              )
            : surface,
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
    this.blurred = true,
    this.semanticLabel,
    this.semanticHint,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glow;
  final double blur;

  /// See [GlassPanel.blurred].
  final bool blurred;

  /// Announced by screen readers in place of the panel's contents.
  final String? semanticLabel;
  final String? semanticHint;

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
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      // The label already describes the control; without this a screen reader
      // would read every nested Text as well.
      excludeSemantics: widget.semanticLabel != null,
      child: GestureDetector(
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
            blurred: widget.blurred,
            glow: widget.glow,
            glowOpacity: _down ? 0.34 : 0.18,
            fill: _down ? AppColors.glassFillStrong : AppColors.glassFill,
            borderColor: _down
                ? AppColors.glassBorderStrong
                : AppColors.glassBorder,
            child: widget.child,
          ),
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
      semanticLabel: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: active ? accent : AppColors.textMid),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            builder: (BuildContext context, Color? value, Widget? _) =>
                Icon(icon, size: 20, color: value ?? AppColors.textMid),
          ),
        ),
      ),
    );

    // The painted circle can be smaller than the 48dp both platforms ask for,
    // so the touch area is expanded around it rather than the visual.
    final Widget sized = TapTarget(child: button);

    if (tooltip == null) return sized;
    return Tooltip(message: tooltip!, child: sized);
  }
}

/// Guarantees a child meets the platform minimum touch target (48dp on
/// Android, 44pt on iOS) without changing how big it looks.
///
/// Several controls here are deliberately small — a 20dp star, a 16dp close
/// icon — which reads well but is hard to hit and fails both stores'
/// accessibility guidance.
class TapTarget extends StatelessWidget {
  const TapTarget({super.key, required this.child, this.size = 48});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      ),
    );
  }
}
