import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/color_utils.dart';

class GlobalStyleConfig {
  final String primaryColor;
  final String surfaceColor;
  final bool isDarkText;
  final String? backgroundImagePath;
  final double bgOverlayOpacity;
  final double bgBlurSigma;

  const GlobalStyleConfig({
    required this.primaryColor,
    required this.surfaceColor,
    required this.isDarkText,
    this.backgroundImagePath,
    required this.bgOverlayOpacity,
    required this.bgBlurSigma,
  });

  Color get primary => ColorUtils.fromHex(primaryColor);
  Color get surface => ColorUtils.fromHex(surfaceColor);
  Color get textColor =>
      isDarkText ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get secondaryTextColor =>
      isDarkText ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

  GlobalStyleConfig copyWith({
    String? primaryColor,
    String? surfaceColor,
    bool? isDarkText,
    String? backgroundImagePath,
    bool clearBackgroundImage = false,
    double? bgOverlayOpacity,
    double? bgBlurSigma,
  }) {
    return GlobalStyleConfig(
      primaryColor: primaryColor ?? this.primaryColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      isDarkText: isDarkText ?? this.isDarkText,
      backgroundImagePath: clearBackgroundImage
          ? null
          : (backgroundImagePath ?? this.backgroundImagePath),
      bgOverlayOpacity: bgOverlayOpacity ?? this.bgOverlayOpacity,
      bgBlurSigma: bgBlurSigma ?? this.bgBlurSigma,
    );
  }

  Map<String, dynamic> toJson() => {
        'primaryColor': primaryColor,
        'surfaceColor': surfaceColor,
        'isDarkText': isDarkText,
        'backgroundImagePath': backgroundImagePath,
        'bgOverlayOpacity': bgOverlayOpacity,
        'bgBlurSigma': bgBlurSigma,
      };

  factory GlobalStyleConfig.fromJson(Map<String, dynamic> json) {
    return GlobalStyleConfig(
      primaryColor: json['primaryColor'] as String? ?? '#FF4F46E5',
      surfaceColor: json['surfaceColor'] as String? ?? '#E6FFFFFF',
      isDarkText: json['isDarkText'] as bool? ?? true,
      backgroundImagePath: json['backgroundImagePath'] as String?,
      bgOverlayOpacity: (json['bgOverlayOpacity'] as num?)?.toDouble() ?? 0.2,
      bgBlurSigma: (json['bgBlurSigma'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DayTypeItemStyle {
  final String badgeText;
  final String badgeColor;
  final String borderColor;
  final double borderWidth;
  final String borderStyle; // 'solid' or 'dashed'
  final String tintOverlayColor;
  final String badgeStyle; // 'pill' or 'ribbon'

  const DayTypeItemStyle({
    required this.badgeText,
    required this.badgeColor,
    required this.borderColor,
    required this.borderWidth,
    required this.borderStyle,
    required this.tintOverlayColor,
    this.badgeStyle = 'pill',
  });

  Color get badgeColorObj => ColorUtils.fromHex(badgeColor);
  Color get borderColorObj => ColorUtils.fromHex(borderColor);
  Color get tintOverlayColorObj => ColorUtils.fromHex(tintOverlayColor);
  bool get isDashed => borderStyle == 'dashed';
  bool get isRibbon => badgeStyle == 'ribbon';

  DayTypeItemStyle copyWith({
    String? badgeText,
    String? badgeColor,
    String? borderColor,
    double? borderWidth,
    String? borderStyle,
    String? tintOverlayColor,
    String? badgeStyle,
  }) {
    return DayTypeItemStyle(
      badgeText: badgeText ?? this.badgeText,
      badgeColor: badgeColor ?? this.badgeColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderStyle: borderStyle ?? this.borderStyle,
      tintOverlayColor: tintOverlayColor ?? this.tintOverlayColor,
      badgeStyle: badgeStyle ?? this.badgeStyle,
    );
  }

  Map<String, dynamic> toJson() => {
        'badgeText': badgeText,
        'badgeColor': badgeColor,
        'borderColor': borderColor,
        'borderWidth': borderWidth,
        'borderStyle': borderStyle,
        'tintOverlayColor': tintOverlayColor,
        'badgeStyle': badgeStyle,
      };

  factory DayTypeItemStyle.fromJson(Map<String, dynamic> json) {
    return DayTypeItemStyle(
      badgeText: json['badgeText'] as String? ?? '工作日',
      badgeColor: json['badgeColor'] as String? ?? '#FF2563EB',
      borderColor: json['borderColor'] as String? ?? '#FFCBD5E1',
      borderWidth: (json['borderWidth'] as num?)?.toDouble() ?? 1.0,
      borderStyle: json['borderStyle'] as String? ?? 'solid',
      tintOverlayColor: json['tintOverlayColor'] as String? ?? '#00000000',
      badgeStyle: (json['badgeStyle'] as String?) == 'ribbon' ? 'ribbon' : 'pill',
    );
  }
}

class DayTypeStyleConfig {
  final DayTypeItemStyle workday;
  final DayTypeItemStyle restDay;

  const DayTypeStyleConfig({
    required this.workday,
    required this.restDay,
  });

  DayTypeStyleConfig copyWith({
    DayTypeItemStyle? workday,
    DayTypeItemStyle? restDay,
  }) {
    return DayTypeStyleConfig(
      workday: workday ?? this.workday,
      restDay: restDay ?? this.restDay,
    );
  }

  Map<String, dynamic> toJson() => {
        'workday': workday.toJson(),
        'restDay': restDay.toJson(),
      };

  factory DayTypeStyleConfig.fromJson(Map<String, dynamic> json) {
    return DayTypeStyleConfig(
      workday: DayTypeItemStyle.fromJson(
        (json['workday'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      restDay: DayTypeItemStyle.fromJson(
        (json['restDay'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
    );
  }
}

class CategoryStyleConfig {
  final String themeColor;
  final String? backgroundImagePath;
  final double cardOverlayOpacity;
  final double cardBlurSigma;

  const CategoryStyleConfig({
    required this.themeColor,
    this.backgroundImagePath,
    required this.cardOverlayOpacity,
    required this.cardBlurSigma,
  });

  Color get color => ColorUtils.fromHex(themeColor);

  CategoryStyleConfig copyWith({
    String? themeColor,
    String? backgroundImagePath,
    bool clearBackgroundImage = false,
    double? cardOverlayOpacity,
    double? cardBlurSigma,
  }) {
    return CategoryStyleConfig(
      themeColor: themeColor ?? this.themeColor,
      backgroundImagePath: clearBackgroundImage
          ? null
          : (backgroundImagePath ?? this.backgroundImagePath),
      cardOverlayOpacity: cardOverlayOpacity ?? this.cardOverlayOpacity,
      cardBlurSigma: cardBlurSigma ?? this.cardBlurSigma,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeColor': themeColor,
        'backgroundImagePath': backgroundImagePath,
        'cardOverlayOpacity': cardOverlayOpacity,
        'cardBlurSigma': cardBlurSigma,
      };

  factory CategoryStyleConfig.fromJson(Map<String, dynamic> json) {
    return CategoryStyleConfig(
      themeColor: json['themeColor'] as String? ?? '#FF64748B',
      backgroundImagePath: json['backgroundImagePath'] as String?,
      cardOverlayOpacity:
          (json['cardOverlayOpacity'] as num?)?.toDouble() ?? 0.4,
      cardBlurSigma: (json['cardBlurSigma'] as num?)?.toDouble() ?? 2.0,
    );
  }
}

/// A reusable card style bundle stored in a theme's candidate pool (`cardStylePool`).
class CardStylePreset {
  final String id;
  final String name;
  final String? defaultCategory;
  final CategoryStyleConfig style;

  const CardStylePreset({
    required this.id,
    required this.name,
    this.defaultCategory,
    required this.style,
  });

  CardStylePreset copyWith({
    String? id,
    String? name,
    String? defaultCategory,
    CategoryStyleConfig? style,
  }) {
    return CardStylePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultCategory: defaultCategory ?? this.defaultCategory,
      style: style ?? this.style,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (defaultCategory != null && defaultCategory!.isNotEmpty)
          'defaultCategory': defaultCategory,
        ...style.toJson(),
      };

  factory CardStylePreset.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim() ??
        (json['defaultCategory'] as String?)?.trim() ??
        '候选样式';
    final id = (json['id'] as String?)?.trim();
    return CardStylePreset(
      id: (id != null && id.isNotEmpty)
          ? id
          : 'preset_${name.hashCode.abs()}_${(json['backgroundImagePath'] ?? '').hashCode.abs()}',
      name: name,
      defaultCategory: (json['defaultCategory'] as String?)?.trim(),
      style: CategoryStyleConfig.fromJson(json),
    );
  }
}

class ThemeConfig {
  final GlobalStyleConfig globalStyle;
  final DayTypeStyleConfig dayTypeStyle;

  /// Keyed internally by categoryId (fallback lookup by categoryName supported for legacy/seed imports).
  final Map<String, CategoryStyleConfig> categoryStyles;

  /// Theme-scoped candidate pool of reusable card style bundles (imported & user-created).
  final List<CardStylePreset> cardStylePool;

  const ThemeConfig({
    required this.globalStyle,
    required this.dayTypeStyle,
    required this.categoryStyles,
    this.cardStylePool = const [],
  });

  CategoryStyleConfig styleForCategory({
    required String categoryId,
    required String categoryName,
    required String defaultColorHex,
  }) {
    return categoryStyles[categoryId] ??
        categoryStyles[categoryName] ??
        CategoryStyleConfig(
          themeColor: defaultColorHex,
          backgroundImagePath: null,
          cardOverlayOpacity: globalStyle.isDarkText ? 0.40 : 0.55,
          cardBlurSigma: globalStyle.isDarkText ? 2.0 : 4.0,
        );
  }

  ThemeConfig copyWith({
    GlobalStyleConfig? globalStyle,
    DayTypeStyleConfig? dayTypeStyle,
    Map<String, CategoryStyleConfig>? categoryStyles,
    List<CardStylePreset>? cardStylePool,
  }) {
    return ThemeConfig(
      globalStyle: globalStyle ?? this.globalStyle,
      dayTypeStyle: dayTypeStyle ?? this.dayTypeStyle,
      categoryStyles: categoryStyles ?? this.categoryStyles,
      cardStylePool: cardStylePool ?? this.cardStylePool,
    );
  }

  Map<String, dynamic> toJson() => {
        'globalStyle': globalStyle.toJson(),
        'dayTypeStyle': dayTypeStyle.toJson(),
        'categoryStyles':
            categoryStyles.map((k, v) => MapEntry(k, v.toJson())),
        if (cardStylePool.isNotEmpty)
          'cardStylePool': cardStylePool.map((e) => e.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  factory ThemeConfig.fromJson(Map<String, dynamic> json) {
    final rawCats =
        (json['categoryStyles'] as Map?)?.cast<String, dynamic>() ?? {};
    final parsedCats = <String, CategoryStyleConfig>{};
    for (final entry in rawCats.entries) {
      if (entry.value is Map) {
        parsedCats[entry.key] = CategoryStyleConfig.fromJson(
          (entry.value as Map).cast<String, dynamic>(),
        );
      }
    }

    final rawPool = (json['cardStylePool'] as List?) ?? const [];
    final parsedPool = <CardStylePreset>[];
    for (final item in rawPool) {
      if (item is Map) {
        parsedPool.add(
          CardStylePreset.fromJson(item.cast<String, dynamic>()),
        );
      }
    }

    return ThemeConfig(
      globalStyle: GlobalStyleConfig.fromJson(
        (json['globalStyle'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      dayTypeStyle: DayTypeStyleConfig.fromJson(
        (json['dayTypeStyle'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      categoryStyles: parsedCats,
      cardStylePool: parsedPool,
    );
  }

  factory ThemeConfig.fromJsonString(String jsonStr) {
    return ThemeConfig.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }
}

class AppThemeRecord {
  final String id;
  final String name;
  final bool isBuiltin;
  final ThemeConfig config;
  final int updatedAt;

  const AppThemeRecord({
    required this.id,
    required this.name,
    required this.isBuiltin,
    required this.config,
    required this.updatedAt,
  });

  AppThemeRecord copyWith({
    String? id,
    String? name,
    bool? isBuiltin,
    ThemeConfig? config,
    int? updatedAt,
  }) {
    return AppThemeRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      config: config ?? this.config,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'is_builtin': isBuiltin ? 1 : 0,
        'config_json': config.toJsonString(),
        'updated_at': updatedAt,
      };

  factory AppThemeRecord.fromMap(Map<String, dynamic> map) {
    final rawBuiltin = map['is_builtin'];
    return AppThemeRecord(
      id: map['id'] as String,
      name: map['name'] as String,
      isBuiltin: rawBuiltin == true || rawBuiltin == 1,
      config: ThemeConfig.fromJsonString(map['config_json'] as String),
      updatedAt: (map['updated_at'] as num?)?.toInt() ?? 0,
    );
  }
}
