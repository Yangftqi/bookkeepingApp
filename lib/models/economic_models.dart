import 'dart:convert';

class EconomicMetric {
  final String id;
  final String name;
  final String description;

  /// 'total_expense' or 'manual_base'
  final String denominatorType;
  final List<String> suggestedCategoryKeywords;
  final bool isBuiltin;
  final int updatedAt;

  const EconomicMetric({
    required this.id,
    required this.name,
    required this.description,
    required this.denominatorType,
    required this.suggestedCategoryKeywords,
    required this.isBuiltin,
    required this.updatedAt,
  });

  EconomicMetric copyWith({
    String? id,
    String? name,
    String? description,
    String? denominatorType,
    List<String>? suggestedCategoryKeywords,
    bool? isBuiltin,
    int? updatedAt,
  }) {
    return EconomicMetric(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      denominatorType: denominatorType ?? this.denominatorType,
      suggestedCategoryKeywords:
          suggestedCategoryKeywords ?? this.suggestedCategoryKeywords,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'denominator_type': denominatorType,
        'suggested_category_keywords': jsonEncode(suggestedCategoryKeywords),
        'is_builtin': isBuiltin ? 1 : 0,
        'updated_at': updatedAt,
      };

  factory EconomicMetric.fromMap(Map<String, dynamic> map) {
    final rawKw = map['suggested_category_keywords'];
    List<String> keywords = [];
    if (rawKw is String && rawKw.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawKw);
        if (decoded is List) {
          keywords = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (rawKw is List) {
      keywords = rawKw.map((e) => e.toString()).toList();
    }
    final rawBuiltin = map['is_builtin'];
    return EconomicMetric(
      id: map['id'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      denominatorType:
          (map['denominator_type'] as String?) ?? 'total_expense',
      suggestedCategoryKeywords: keywords,
      isBuiltin: rawBuiltin == true || rawBuiltin == 1,
      updatedAt: (map['updated_at'] as num?)?.toInt() ?? 0,
    );
  }
}

class EconomicBenchmark {
  final String id;
  final String metricId;
  final String name;
  final bool isTierStandard;
  final double value;
  final double? maxValue;
  final String note;

  const EconomicBenchmark({
    required this.id,
    required this.metricId,
    required this.name,
    required this.isTierStandard,
    required this.value,
    this.maxValue,
    required this.note,
  });

  EconomicBenchmark copyWith({
    String? id,
    String? metricId,
    String? name,
    bool? isTierStandard,
    double? value,
    double? maxValue,
    String? note,
  }) {
    return EconomicBenchmark(
      id: id ?? this.id,
      metricId: metricId ?? this.metricId,
      name: name ?? this.name,
      isTierStandard: isTierStandard ?? this.isTierStandard,
      value: value ?? this.value,
      maxValue: maxValue ?? this.maxValue,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'metric_id': metricId,
        'name': name,
        'is_tier_standard': isTierStandard ? 1 : 0,
        'value': value,
        'max_value': maxValue,
        'note': note,
      };

  factory EconomicBenchmark.fromMap(Map<String, dynamic> map) {
    final rawTier = map['is_tier_standard'];
    return EconomicBenchmark(
      id: map['id'] as String,
      metricId: map['metric_id'] as String,
      name: map['name'] as String,
      isTierStandard: rawTier == true || rawTier == 1,
      value: (map['value'] as num).toDouble(),
      maxValue: (map['max_value'] as num?)?.toDouble(),
      note: (map['note'] as String?) ?? '',
    );
  }
}

class EconomicComparisonSnapshot {
  final String metricName;
  final double myValuePercent;
  final String? matchedTierName;
  final String? matchedTierNote;
  final double? percentileFromLow;
  final int totalSamples;
  final List<String> selectedCategoryNames;
  final double numeratorAmount;
  final double denominatorAmount;

  const EconomicComparisonSnapshot({
    required this.metricName,
    required this.myValuePercent,
    this.matchedTierName,
    this.matchedTierNote,
    this.percentileFromLow,
    required this.totalSamples,
    required this.selectedCategoryNames,
    required this.numeratorAmount,
    required this.denominatorAmount,
  });
}
