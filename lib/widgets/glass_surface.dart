import 'package:flutter/material.dart';

import '../models/theme_config.dart';

/// Zero-lag high-translucency light glass panel.
/// Uses pure alpha compositing + 1px glass edge highlight (no expensive per-frame
/// BackdropFilter passes), ensuring 120fps scrolling and 100% consistent translucency
/// on both static and scrollable screens.
class GlassSurface extends StatelessWidget {
  final ThemeConfig themeConfig;
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;

  const GlassSurface({
    super.key,
    required this.themeConfig,
    required this.child,
    this.borderRadius = 18,
    this.padding,
    this.margin,
    this.border,
  });

  static Color resolvedSurfaceColor(
    ThemeConfig themeConfig, {
    bool forBar = false,
  }) {
    final g = themeConfig.globalStyle;
    final hasBg =
        g.backgroundImagePath != null && g.backgroundImagePath!.isNotEmpty;
    final base = g.surface;
    if (!hasBg) {
      return base;
    }
    // High-translucency light glass when a global background image is active,
    // while respecting even lower user-chosen surfaceColor alpha values.
    final maxAlpha = forBar ? 0.64 : 0.54;
    final currentAlpha = base.opacity;
    final effectiveAlpha = currentAlpha > maxAlpha ? maxAlpha : currentAlpha;
    return base.withOpacity(effectiveAlpha.clamp(0.24, 0.85));
  }

  @override
  Widget build(BuildContext context) {
    final g = themeConfig.globalStyle;
    final hasBg =
        g.backgroundImagePath != null && g.backgroundImagePath!.isNotEmpty;
    final fillColor = resolvedSurfaceColor(themeConfig);
    final subtleBorder = border ??
        Border.all(
          color: (g.isDarkText ? Colors.white : Colors.white)
              .withOpacity(hasBg ? 0.42 : 0.14),
          width: 1.0,
        );

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: subtleBorder,
      ),
      child: child,
    );

    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: content,
    );

    if (margin != null) {
      return Padding(padding: margin!, child: clipped);
    }
    return clipped;
  }
}
