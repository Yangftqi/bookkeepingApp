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
    if (minimalistMode) {
      return _buildMinimalistCard(context);
    }
    return _buildStandardCard(context);
  }

  /// Ultra-compact Minimalist Card:
  /// - Independent of illustrated card's pill/ribbon toggle
  /// - Left: Category pill + DateTime stacked tightly
  /// - Middle: Note (1 line)
  /// - Right-middle: Amount
  /// - Far-right edge: Vertical Workday/Rest-day strip
  Widget _buildMinimalistCard(BuildContext context) {
    final g = themeConfig.globalStyle;
    final catStyle = themeConfig.styleForCategory(
      categoryId: category.id,
      categoryName: category.name,
      defaultColorHex: category.defaultColorHex,
    );
    final dayStyle = expense.isRestDay
        ? themeConfig.dayTypeStyle.restDay
        : themeConfig.dayTypeStyle.workday;

    final glassFill = GlassSurface.resolvedSurfaceColor(themeConfig);
    final verticalDayText = dayStyle.badgeText.split('').join('\n');
    final dtStr = DateUtilsExt.toDateTimeStr(expense.dateTime);
    final compactDt = dtStr.length >= 16 ? dtStr.substring(5) : dtStr;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: BorderedCardContainer(
        borderColor: isSelected ? g.primary : dayStyle.borderColorObj,
        borderWidth: isSelected ? 2.2 : dayStyle.borderWidth,
        isDashed: !isSelected && dayStyle.isDashed,
        borderRadius: 12,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: glassFill)),
                if (dayStyle.tintOverlayColorObj.alpha > 0)
                  Positioned.fill(
                    child: ColoredBox(color: dayStyle.tintOverlayColorObj),
                  ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left 4px category accent bar
                      Container(width: 4, color: catStyle.color),
                      if (selectionMode)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (_) => onTap?.call(),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      // Left column: Category + DateTime
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: catStyle.color.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: catStyle.color.withOpacity(0.65),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                category.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: g.isDarkText
                                      ? catStyle.color
                                      : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2.5),
                            Text(
                              compactDt,
                              style: TextStyle(
                                fontSize: 10,
                                color: g.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Middle: Note
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            expense.note.trim().isEmpty
                                ? '无备注'
                                : expense.note.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: expense.note.trim().isEmpty
                                  ? g.secondaryTextColor.withOpacity(0.75)
                                  : g.textColor,
                            ),
                          ),
                        ),
                      ),
                      // Right-middle: Amount
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Center(
                          child: Text(
                            '-$currencyPrefix${expense.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: g.textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                      // Far-right edge: Vertical Workday/Rest-day strip
                      Container(
                        width: 19,
                        color: dayStyle.badgeColorObj.withOpacity(0.92),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          verticalDayText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 8.5,
                            height: 1.12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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

  Widget _buildStandardCard(BuildContext context) {
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
    final hasCatImage =
        catBgPath != null && catBgPath.isNotEmpty && File(catBgPath).existsSync();

    // Directional gradient scrim for illustrated cards
    final scrimBase = g.isDarkText ? Colors.white : Colors.black;
    final op = catStyle.cardOverlayOpacity.clamp(0.0, 0.92);
    final leftOp = (op * 1.18).clamp(0.18, 0.92);
    final midOp = (op * 0.58).clamp(0.05, 0.85);
    final rightOp = (op * 1.05).clamp(0.16, 0.90);

    final panelBackingColor =
        (g.isDarkText ? Colors.white : const Color(0xFF0F172A))
            .withOpacity(hasCatImage ? 0.78 : 0.0);
    final panelBorderColor =
        (g.isDarkText ? catStyle.color : Colors.white)
            .withOpacity(hasCatImage ? 0.28 : 0.0);

    final cardGlassFill = GlassSurface.resolvedSurfaceColor(themeConfig);

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: BorderedCardContainer(
        borderColor: isSelected ? g.primary : dayStyle.borderColorObj,
        borderWidth: isSelected ? 2.4 : dayStyle.borderWidth,
        isDashed: !isSelected && dayStyle.isDashed,
        borderRadius: 16,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              children: [
                Positioned.fill(
                  child: cardImageLayer ?? ColoredBox(color: cardGlassFill),
                ),
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
                if (dayStyle.tintOverlayColorObj.alpha > 0)
                  Positioned.fill(
                    child: ColoredBox(color: dayStyle.tintOverlayColorObj),
                  ),
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
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 6, color: catStyle.color),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            11,
                            10,
                            dayStyle.isRibbon ? 14 : 11,
                            10,
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
                                child: hasCatImage
                                    ? _buildIllustratedCardContent(
                                        g: g,
                                        catStyle: catStyle,
                                        dayStyle: dayStyle,
                                        panelBackingColor: panelBackingColor,
                                        panelBorderColor: panelBorderColor,
                                      )
                                    : _buildPlainCardContent(
                                        g: g,
                                        catStyle: catStyle,
                                        dayStyle: dayStyle,
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

  /// Scheme A: Unified compact frosted info panel on the left (Category + Time + Note)
  /// paired with a matching frosted amount badge on the bottom-right, leaving the center
  /// illustration open and legible.
  Widget _buildIllustratedCardContent({
    required GlobalStyleConfig g,
    required CategoryStyleConfig catStyle,
    required DayTypeItemStyle dayStyle,
    required Color panelBackingColor,
    required Color panelBorderColor,
  }) {
    final trimmedNote = expense.note.trim();
    final hasNote = trimmedNote.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: panelBackingColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: panelBorderColor, width: 0.9),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: catStyle.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: g.textColor,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3.5),
                  Text(
                    DateUtilsExt.toDateTimeStr(expense.dateTime),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: g.secondaryTextColor,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3.5),
                  Text(
                    hasNote ? trimmedNote : '无备注',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasNote
                          ? g.textColor
                          : g.secondaryTextColor.withOpacity(0.82),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!dayStyle.isRibbon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: dayStyle.badgeColorObj,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dayStyle.badgeText,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              )
            else
              const SizedBox(height: 18),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: panelBackingColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: panelBorderColor, width: 0.9),
              ),
              child: Text(
                '-$currencyPrefix${expense.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                  color: g.textColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Plain glass card content (when no category illustration is set).
  Widget _buildPlainCardContent({
    required GlobalStyleConfig g,
    required CategoryStyleConfig catStyle,
    required DayTypeItemStyle dayStyle,
  }) {
    final trimmedNote = expense.note.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: catStyle.color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: catStyle.color.withOpacity(0.75),
                  width: 1.0,
                ),
              ),
              child: Text(
                category.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: g.isDarkText ? catStyle.color : Colors.white,
                ),
              ),
            ),
            const Spacer(),
            if (!dayStyle.isRibbon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: dayStyle.badgeColorObj,
                  borderRadius: BorderRadius.circular(20),
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
        const SizedBox(height: 5),
        Text(
          DateUtilsExt.toDateTimeStr(expense.dateTime),
          style: TextStyle(
            fontSize: 11.5,
            color: g.secondaryTextColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                trimmedNote.isEmpty ? '无备注' : trimmedNote,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  color: trimmedNote.isEmpty
                      ? g.secondaryTextColor.withOpacity(0.8)
                      : g.textColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '-$currencyPrefix${expense.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: g.textColor,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
