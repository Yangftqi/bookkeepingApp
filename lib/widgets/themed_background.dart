import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/theme_config.dart';

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
    final hasImage = bgPath != null && bgPath.isNotEmpty && File(bgPath).existsSync();
    final baseBgColor =
        g.isDarkText ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final overlayColor = (g.isDarkText ? Colors.white : Colors.black)
        .withOpacity(g.bgOverlayOpacity.clamp(0.0, 0.95));

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: baseBgColor),
        if (hasImage)
          Image(
            image: ResizeImage.resizeIfNeeded(
              1440,
              null,
              FileImage(File(bgPath)),
            ),
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        if (hasImage && g.bgBlurSigma > 0.1)
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: g.bgBlurSigma,
              sigmaY: g.bgBlurSigma,
            ),
            child: const SizedBox.expand(),
          ),
        if (hasImage) ColoredBox(color: overlayColor),
        child,
      ],
    );
  }
}
