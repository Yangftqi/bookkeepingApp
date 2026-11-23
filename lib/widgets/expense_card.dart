import 'dart:io';
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

    // Directional gradient scrim for illustrated cards:
    // Stronger readability on the left (category + note) and right edge (amount),
    // clearer visual window in the center-right so anime character art shines cleanly!
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

    final minimalistFill = GlassSurface.resolvedSurfaceColor(themeConfig)
        .withOpacity(minimalistMode && hasGlobalBg ? 0.58 : 0.72);

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
                // Base layer: Category background image OR frosted translucent surface
                Positioned.fill(
                  child: hasCatImage
                      ? Image(
                          image: ResizeImage.resizeIfNeeded(
                            960,
                            null,
                            FileImage(File(catBgPath)),
                          ),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      : hasGlobalBg
                          ? BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: ColoredBox(color: minimalistFill),
                            )
                          : ColoredBox(color: g.surface),
                ),
                // Blur on illustrated category card
                if (hasCatImage && catStyle.cardBlurSigma > 0.1)
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: catStyle.cardBlurSigma,
                        sigmaY: catStyle.cardBlurSigma,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                // Directional gradient readability scrim on illustrated category card
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
                // Foreground content with left category accent bar
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
                            minimalistMode ? 8 : 11,
                            11,
                            minimalistMode ? 8 : 11,
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
                                    Row(
                                      children: [
                                        // Category name pill with frosted backing on illustrated cards
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
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            DateUtilsExt.toDateTimeStr(
                                              expense.dateTime,
                                            ),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: g.secondaryTextColor,
                                              shadows: textShadows,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Top-right Day-type badge pill
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
                                    SizedBox(height: minimalistMode ? 5 : 8),
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
                                        // Amount with frosted pill backing on illustrated cards
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
