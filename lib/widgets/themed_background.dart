import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/theme_config.dart';

/// Renders the global background with RepaintBoundary-cached ImageFiltered blur
/// (avoids per-frame BackdropFilter framebuffer copies for silky 120fps scrolling).
class ThemedBackground extends StatelessWidget {
  final ThemeConfig themeConfig;
  final Widget child;

  const ThemedBackground({
    super.key,
    required this.themeConfig,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final g = themeConfig.globalStyle;
    final bgPath = g.backgroundImagePath;
    final hasImage =
        bgPath != null && bgPath.isNotEmpty && File(bgPath).existsSync();
    final baseBgColor =
        g.isDarkText ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final overlayColor = (g.isDarkText ? Colors.white : Colors.black)
        .withOpacity(g.bgOverlayOpacity.clamp(0.0, 0.95));

    Widget? bgImageWidget;
    if (hasImage) {
      final rawImage = Image(
        image: ResizeImage.resizeIfNeeded(
          1440,
          null,
          FileImage(File(bgPath)),
        ),
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
      bgImageWidget = RepaintBoundary(
        child: g.bgBlurSigma > 0.1
            ? ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: g.bgBlurSigma,
                  sigmaY: g.bgBlurSigma,
                  tileMode: TileMode.clamp,
                ),
                child: rawImage,
              )
            : rawImage,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: baseBgColor),
        if (bgImageWidget != null) bgImageWidget,
        if (hasImage && g.bgOverlayOpacity > 0.005)
          IgnorePointer(child: ColoredBox(color: overlayColor)),
        child,
      ],
    );
  }
}
