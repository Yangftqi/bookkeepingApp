import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../models/theme_config.dart';
import '../utils/date_utils_ext.dart';
import 'dashed_border.dart';
import 'glass_surface.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final ExpenseCategory category;
  final ThemeConfig themeConfig;
  final String currencyPrefix;
  final bool selectionMode;
  final bool isSelected;
  final bool minimalistMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ExpenseCard({
    super.key,
    required this.expense,
    required this.category,
    required this.themeConfig,
    required this.currencyPrefix,
    this.selectionMode = false,
    this.isSelected = false,
    this.minimalistMode = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final g = themeConfig.globalStyle;
    final catStyle = themeConfig.styleForCategory(
      categoryId: category.id,
      categoryName: category.name,
      defaultColorHex: category.defaultColorHex,
    );
    final dayStyle = expense.isRestDay
        ? themeConfig.dayTypeStyle.restDay
        : themeConfig.dayTypeStyle.workday;

    final catBgPath = catStyle.backgroundImagePath;
    final hasCatImage = !minimalistMode &&
        catBgPath != null &&
        catBgPath.isNotEmpty &&
        File(catBgPath).existsSync();

    final hasGlobalBg =
        g.backgroundImagePath != null && g.backgroundImagePath!.isNotEmpty;

    // Directional gradient scrim for illustrated cards
    final scrimBase = g.isDarkText ? Colors.white : Colors.black;
    final op = catStyle.cardOverlayOpacity.clamp(0.0, 0.92);
    final leftOp = (op * 1.18).clamp(0.18, 0.92);
    final midOp = (op * 0.58).clamp(0.05, 0.85);
    final rightOp = (op * 1.05).clamp(0.16, 0.90);

    final textShadows = hasCatImage
        ? <Shadow>[
            Shadow(
              color: (g.isDarkText ? Colors.white : Colors.black)
                  .withOpacity(0.75),
              blurRadius: 6,
            ),
          ]
        : null;

    final pillBackingColor = (g.isDarkText ? Colors.white : Colors.black)
        .withOpacity(hasCatImage ? 0.68 : 0.0);

    // Zero-blur high-translucency light glass fill (120fps silky smooth!)
    final cardGlassFill = GlassSurface.resolvedSurfaceColor(themeConfig)
        .withOpacity(minimalistMode && hasGlobalBg ? 0.46 : 0.56);

    Widget? cardImageLayer;
    if (hasCatImage) {
      final rawImg = Image(
        image: ResizeImage.resizeIfNeeded(
          960,
          null,
          FileImage(File(catBgPath)),
        ),
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
      cardImageLayer = RepaintBoundary(
        child: catStyle.cardBlurSigma > 0.1
            ? ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: catStyle.cardBlurSigma,
                  sigmaY: catStyle.cardBlurSigma,
                  tileMode: TileMode.clamp,
                ),
                child: rawImg,
              )
            : rawImg,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: minimalistMode ? 3.5 : 5,
      ),
      child: BorderedCardContainer(
        borderColor: isSelected ? g.primary : dayStyle.borderColorObj,
        borderWidth: isSelected ? 2.4 : dayStyle.borderWidth,
        isDashed: !isSelected && dayStyle.isDashed,
        borderRadius: minimalistMode ? 14 : 16,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              children: [
                // Base layer: Cached blurred category image OR zero-blur translucent glass surface
                Positioned.fill(
                  child: cardImageLayer ??
                      ColoredBox(color: hasGlobalBg ? cardGlassFill : g.surface),
                ),
                // Directional gradient readability scrim on illustrated card
                if (hasCatImage)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: const [0.0, 0.52, 0.78, 1.0],
                          colors: [
                            scrimBase.withOpacity(leftOp),
                            scrimBase.withOpacity(midOp),
                            scrimBase.withOpacity(midOp * 0.9),
                            scrimBase.withOpacity(rightOp),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Workday / Rest-day tint overlay
                if (dayStyle.tintOverlayColorObj.alpha > 0)
                  Positioned.fill(
                    child: ColoredBox(color: dayStyle.tintOverlayColorObj),
                  ),
                // Optional Diagonal Corner Ribbon (top-right)
                if (dayStyle.isRibbon)
                  Positioned(
                    top: 10,
                    right: -24,
                    child: IgnorePointer(
                      child: Transform.rotate(
                        angle: math.pi / 4,
                        child: Container(
                          width: 88,
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: dayStyle.badgeColorObj.withOpacity(0.92),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            dayStyle.badgeText,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Foreground 3-line layout:
                // Row 1: Category pill (left) + Day-type pill badge (right, if not ribbon)
                // Row 2: Date & Time (between category and note)
                // Row 3: Note (left) + Amount (right)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: minimalistMode ? 4.5 : 6,
                        color: catStyle.color,
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            11,
                            minimalistMode ? 7 : 10,
                            dayStyle.isRibbon ? 14 : 11,
                            minimalistMode ? 7 : 10,
                          ),
                          child: Row(
                            children: [
                              if (selectionMode) ...[
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => onTap?.call(),
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Line 1: Category pill + optional Pill badge
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: hasCatImage
                                                ? pillBackingColor
                                                : catStyle.color
                                                    .withOpacity(0.18),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: catStyle.color
                                                  .withOpacity(0.75),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Text(
                                            category.name,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: g.isDarkText
                                                  ? catStyle.color
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (!dayStyle.isRibbon)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: dayStyle.badgeColorObj,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              dayStyle.badgeText,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: minimalistMode ? 3 : 5),
                                    // Line 2: Date & Time (between category and note)
                                    Text(
                                      DateUtilsExt.toDateTimeStr(
                                        expense.dateTime,
                                      ),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: g.secondaryTextColor,
                                        shadows: textShadows,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: minimalistMode ? 3 : 5),
                                    // Line 3: Note (left) + Amount (right)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            expense.note.trim().isEmpty
                                                ? '无备注'
                                                : expense.note.trim(),
                                            maxLines: minimalistMode ? 1 : 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: hasCatImage
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              color: expense.note.trim().isEmpty
                                                  ? g.secondaryTextColor
                                                      .withOpacity(0.8)
                                                  : g.textColor,
                                              shadows: textShadows,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: hasCatImage
                                              ? const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                )
                                              : EdgeInsets.zero,
                                          decoration: hasCatImage
                                              ? BoxDecoration(
                                                  color: pillBackingColor,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                )
                                              : null,
                                          child: Text(
                                            '-$currencyPrefix${expense.amount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize:
                                                  minimalistMode ? 16.5 : 18,
                                              fontWeight: FontWeight.w800,
                                              color: g.textColor,
                                              letterSpacing: -0.3,
                                              shadows: textShadows,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
