import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../models/theme_config.dart';
import '../utils/date_utils_ext.dart';
import 'dashed_border.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final ExpenseCategory category;
  final ThemeConfig themeConfig;
  final String currencyPrefix;
  final bool selectionMode;
  final bool isSelected;
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
    final hasCatImage =
        catBgPath != null && catBgPath.isNotEmpty && File(catBgPath).existsSync();
    final readabilityOverlay = (g.isDarkText ? Colors.white : Colors.black)
        .withOpacity(catStyle.cardOverlayOpacity.clamp(0.0, 0.92));

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
                // Base layer: Category background image or global surfaceColor
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
                      : ColoredBox(color: g.surface),
                ),
                // Blur + readability overlay on category image
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
                if (hasCatImage)
                  Positioned.fill(child: ColoredBox(color: readabilityOverlay)),
                // Workday / Rest-day tint overlay
                if (dayStyle.tintOverlayColorObj.alpha > 0)
                  Positioned.fill(
                    child: ColoredBox(color: dayStyle.tintOverlayColorObj),
                  ),
                // Foreground content with 6px left category accent bar
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 6,
                        color: catStyle.color,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
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
                                        // Category name pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: catStyle.color
                                                .withOpacity(0.18),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: catStyle.color
                                                  .withOpacity(0.6),
                                              width: 0.8,
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
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            expense.note.trim().isEmpty
                                                ? '无备注'
                                                : expense.note.trim(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              color: expense.note.trim().isEmpty
                                                  ? g.secondaryTextColor
                                                      .withOpacity(0.75)
                                                  : g.textColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
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
