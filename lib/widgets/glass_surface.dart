import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/theme_config.dart';

/// Frosted glass panel that respects the theme's `surfaceColor` alpha
/// and lets global background artwork breathe through gracefully.
class GlassSurface extends StatelessWidget {
  final ThemeConfig themeConfig;
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blurSigma;
  final Border? border;

  const GlassSurface({
    super.key,
    required this.themeConfig,
    required this.child,
    this.borderRadius = 18,
    this.padding,
    this.margin,
    this.blurSigma = 10.0,
    this.border,
  });

  static Color resolvedSurfaceColor(ThemeConfig themeConfig, {bool forBar = false}) {
    final g = themeConfig.globalStyle;
    final hasBg = g.backgroundImagePath != null && g.backgroundImagePath!.isNotEmpty;
    final base = g.surface;
    if (!hasBg) {
      return base;
    }
    // When a global background image is active, keep panels gracefully translucent
    // while still honoring lower user-chosen surfaceColor alpha values.
    final maxAlpha = forBar ? 0.78 : 0.72;
    final currentAlpha = base.opacity;
    final effectiveAlpha = currentAlpha > maxAlpha ? maxAlpha : currentAlpha;
    return base.withOpacity(effectiveAlpha.clamp(0.28, 0.92));
  }

  @override
  Widget build(BuildContext context) {
    final g = themeConfig.globalStyle;
    final hasBg = g.backgroundImagePath != null && g.backgroundImagePath!.isNotEmpty;
    final fillColor = resolvedSurfaceColor(themeConfig);
    final subtleBorder = border ??
        Border.all(
          color: (g.isDarkText ? Colors.white : Colors.white)
              .withOpacity(hasBg ? 0.35 : 0.14),
          width: 0.9,
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
      child: hasBg && blurSigma > 0.1
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: content,
            )
          : content,
    );

    if (margin != null) {
      return Padding(padding: margin!, child: clipped);
    }
    return clipped;
  }
}
