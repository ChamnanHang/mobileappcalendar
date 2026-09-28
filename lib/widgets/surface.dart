import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A flat card: surface fill and a hairline border. No shadow, no blur.
///
/// This replaced a frosted-glass panel. Besides the look, that also retired
/// the most expensive thing the old UI painted — a `BackdropFilter` costs a
/// `saveLayer` plus a gaussian pass per panel per frame.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppTheme.radiusMd,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Defaults to [AppPalette.surface].
  final Color? color;

  /// Defaults to [AppPalette.border].
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? p.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A [SurfaceCard] that responds to touch by filling in, rather than by the
/// scale-and-glow the old glass panel used.
class TapSurface extends StatefulWidget {
  const TapSurface({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppTheme.radiusMd,
    this.semanticLabel,
    this.semanticHint,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Announced by screen readers in place of the surface's contents.
  final String? semanticLabel;
  final String? semanticHint;

  @override
  State<TapSurface> createState() => _TapSurfaceState();
}

class _TapSurfaceState extends State<TapSurface> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _down ? p.surfaceMuted : p.surface,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: _down ? p.borderStrong : p.border),
          ),
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A borderless round icon button for headers and toolbars.
///
/// Draws nothing at rest but the icon; a press fills a circle of [size] and
/// [active] tints the icon with the accent.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.active = false,
    this.activeColor,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool active;

  /// Defaults to [AppPalette.accent].
  final Color? activeColor;

  /// The visual circle. The touch area is always at least 48dp.
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Widget button = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: 22,
            color: active ? (activeColor ?? p.accent) : p.textSecondary,
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
