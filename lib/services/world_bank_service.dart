import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/economic_models.dart';
import 'llm_service.dart';

class WorldBankService {
  static const _uuid = Uuid();

  /// Engine 2A: Fetches macro indicator data directly from World Bank Open API v2.
  static Future<GeneratedEconomicModel> fetchWorldBankIndicator({
    required String indicatorCode,
    required String customName,
    String description = '',
    List<String> keywords = const [],
  }) async {
    final code = indicatorCode.trim();
    if (code.isEmpty) {
      throw ArgumentError('指标代码不能为空');
    }
    final uri = Uri.parse(
      'https://api.worldbank.org/v2/country/all/indicator/$code?format=json&per_page=100&mrnev=1',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('World Bank API HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List || decoded.length < 2 || decoded[1] is! List) {
      throw Exception('World Bank 返回数据结构异常，请检查指标代码是否正确');
    }

    final rows = decoded[1] as List;
    String indicatorTitle = customName.trim();
    final samples = <Map<String, dynamic>>[];
    final seenNames = <String>{};

    for (final row in rows) {
      if (row is! Map) continue;
      final val = (row['value'] as num?)?.toDouble();
      if (val == null || val < 0 || val > 100) continue;
      final countryObj = row['country'] as Map?;
      final countryName = countryObj?['value']?.toString().trim() ?? '';
      if (countryName.isEmpty || seenNames.contains(countryName)) continue;

      if (indicatorTitle.isEmpty) {
        final indObj = row['indicator'] as Map?;
        indicatorTitle = indObj?['value']?.toString().trim() ?? code;
      }

      // Filter out obvious aggregate regions if we want cleaner country list, keep well-known ones
      final iso3 = row['countryiso3code']?.toString() ?? '';
      if (iso3.isEmpty) continue;

      seenNames.add(countryName);
      final year = row['date']?.toString() ?? '';
      samples.add({
        'name': countryName,
        'value': double.parse(val.toStringAsFixed(2)),
        'note': 'World Bank ($code${year.isNotEmpty ? ', $year' : ''})',
      });
    }

    if (samples.isEmpty) {
      throw Exception('该指标下未获取到有效的百分比国家样本（0~100%）');
    }

    return _buildQuartileModel(
      name: indicatorTitle.isEmpty ? 'World Bank: $code' : indicatorTitle,
      description: description.trim().isNotEmpty
          ? description.trim()
          : '来源于世界银行公开数据 API（指标代码：$code），自动提取各经济体最新年份数据并计算四分位评级区间。',
      keywords: keywords,
      samples: samples,
    );
  }

  /// Engine 2B: Fetches a custom REST JSON URL.
  /// Supports either our standard Economic Model JSON schema OR a flat JSON array
  /// of `{"name": "...", "value": 12.3, "note": "..."}` items.
  static Future<GeneratedEconomicModel> fetchCustomJsonUrl({
    required String url,
    required String fallbackName,
    String description = '',
    List<String> keywords = const [],
  }) async {
    final uri = Uri.parse(url.trim());
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic> && decoded.containsKey('benchmarks')) {
      return LlmService.parseGeneratedEconomicJson(decoded);
    }

    List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map && decoded['data'] is List) {
      list = decoded['data'] as List;
    } else {
      throw const FormatException(
        '无法解析 JSON：请返回标准指标对象或包含 name/value 字段的数组',
      );
    }

    final samples = <Map<String, dynamic>>[];
    for (final item in list) {
      if (item is! Map) continue;
      final name = (item['name'] ?? item['country'] ?? item['label'])
          ?.toString()
          .trim();
      final val = (item['value'] as num?)?.toDouble();
      if (name == null || name.isEmpty || val == null) continue;
      samples.add({
        'name': name,
        'value': double.parse(val.clamp(0.0, 100.0).toStringAsFixed(2)),
        'note': (item['note'] ?? item['source'] ?? '自定义 API').toString(),
      });
    }

    if (samples.isEmpty) {
      throw const FormatException('JSON 数组中未找到有效的 name/value 样本');
    }

    return _buildQuartileModel(
      name: fallbackName.trim().isEmpty ? '自定义 API 经济学模型' : fallbackName.trim(),
      description: description.trim().isNotEmpty
          ? description.trim()
          : '通过自定义 REST JSON 接口拉取的统计对比基准模型。',
      keywords: keywords,
      samples: samples,
    );
  }

  static GeneratedEconomicModel _buildQuartileModel({
    required String name,
    required String description,
    required List<String> keywords,
    required List<Map<String, dynamic>> samples,
  }) {
    samples.sort(
      (a, b) => (a['value'] as double).compareTo(b['value'] as double),
    );
    final values = samples.map((e) => e['value'] as double).toList();
    double quantile(double q) {
      if (values.length == 1) return values.first;
      final idx = (q * (values.length - 1)).clamp(0, values.length - 1);
      final lo = idx.floor();
      final hi = idx.ceil();
      final frac = idx - lo;
      return double.parse(
        (values[lo] * (1 - frac) + values[hi] * frac).toStringAsFixed(1),
      );
    }

    final q25 = quantile(0.25);
    final q50 = quantile(0.50);
    final q75 = quantile(0.75);

    final metricId = 'metric_${_uuid.v4()}';
    final now = DateTime.now().millisecondsSinceEpoch;
    final metric = EconomicMetric(
      id: metricId,
      name: name,
      description: description,
      denominatorType: 'total_expense',
      suggestedCategoryKeywords: keywords,
      isBuiltin: false,
      updatedAt: now,
    );

    final benchmarks = <EconomicBenchmark>[
      EconomicBenchmark(
        id: 'bench_${_uuid.v4()}',
        metricId: metricId,
        name: '低分位区间 (0% ~ $q25%)',
        isTierStandard: true,
        value: 0.0,
        maxValue: q25,
        note: '位于样本库最低 25% 区间',
      ),
      EconomicBenchmark(
        id: 'bench_${_uuid.v4()}',
        metricId: metricId,
        name: '中低分位区间 ($q25% ~ $q50%)',
        isTierStandard: true,
        value: q25,
        maxValue: q50,
        note: '位于样本库 25%~50% 区间',
      ),
      EconomicBenchmark(
        id: 'bench_${_uuid.v4()}',
        metricId: metricId,
        name: '中高分位区间 ($q50% ~ $q75%)',
        isTierStandard: true,
        value: q50,
        maxValue: q75,
        note: '位于样本库 50%~75% 区间',
      ),
      EconomicBenchmark(
        id: 'bench_${_uuid.v4()}',
        metricId: metricId,
        name: '高分位区间 (≥ $q75%)',
        isTierStandard: true,
        value: q75,
        maxValue: 100.0,
        note: '位于样本库最高 25% 区间',
      ),
      ...samples.map(
        (s) => EconomicBenchmark(
          id: 'bench_${_uuid.v4()}',
          metricId: metricId,
          name: s['name'] as String,
          isTierStandard: false,
          value: s['value'] as double,
          maxValue: null,
          note: s['note'] as String,
        ),
      ),
    ];

    return GeneratedEconomicModel(metric: metric, benchmarks: benchmarks);
  }
}
