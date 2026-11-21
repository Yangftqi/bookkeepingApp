import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../data/seed_data.dart';
import '../models/economic_models.dart';

class GeneratedEconomicModel {
  final EconomicMetric metric;
  final List<EconomicBenchmark> benchmarks;

  const GeneratedEconomicModel({
    required this.metric,
    required this.benchmarks,
  });
}

class LlmService {
  static const _uuid = Uuid();

  static Uri _buildChatUri(String baseUrl) {
    var trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.endsWith('/chat/completions')) {
      return Uri.parse(trimmed);
    }
    return Uri.parse('$trimmed/chat/completions');
  }

  static Map<String, String> _headers(String apiKey) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream, application/json',
    };
    if (apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }
    return headers;
  }

  /// Tests connectivity to the OpenAI-compatible API endpoint.
  static Future<String> testConnection({
    required String baseUrl,
    required String apiKey,
    required String modelName,
  }) async {
    final uri = _buildChatUri(baseUrl);
    final body = jsonEncode({
      'model': modelName.trim(),
      'messages': [
        {'role': 'user', 'content': '请回复“连接成功”四个字。'},
      ],
      'max_tokens': 32,
      'stream': false,
    });

    final response = await http
        .post(uri, headers: _headers(apiKey), body: body)
        .timeout(const Duration(seconds: 25));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = decoded['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      return '连接成功（未返回文本）';
    }
    final content =
        (choices.first as Map)['message']?['content']?.toString().trim() ?? '';
    return content.isEmpty ? '连接成功' : content;
  }

  /// Streams delta content tokens from an OpenAI-compatible `/v1/chat/completions` endpoint.
  static Stream<String> streamChat({
    required String baseUrl,
    required String apiKey,
    required String modelName,
    required List<Map<String, String>> messages,
  }) async* {
    final uri = _buildChatUri(baseUrl);
    final client = http.Client();
    try {
      final request = http.Request('POST', uri);
      request.headers.addAll(_headers(apiKey));
      request.body = jsonEncode({
        'model': modelName.trim(),
        'messages': messages,
        'stream': true,
      });

      final streamedResponse =
          await client.send(request).timeout(const Duration(seconds: 45));

      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        final errBody = await streamedResponse.stream.bytesToString();
        throw Exception('HTTP ${streamedResponse.statusCode}: $errBody');
      }

      final lineStream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final rawLine in lineStream) {
        final line = rawLine.trim();
        if (line.isEmpty || !line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload == '[DONE]') break;

        try {
          final jsonObj = jsonDecode(payload) as Map<String, dynamic>;
          final choices = jsonObj['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;
          final delta = (choices.first as Map)['delta'] as Map?;
          final content = delta?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } catch (_) {
          // Skip partial/non-JSON keepalive lines
        }
      }
    } finally {
      client.close();
    }
  }

  /// Engine 1: Uses the configured LLM with Appendix B.2 strict JSON Schema prompt
  /// to generate a complete EconomicMetric + tier standards + 20~30 benchmarks.
  static Future<GeneratedEconomicModel> generateEconomicModel({
    required String baseUrl,
    required String apiKey,
    required String modelName,
    required String topic,
  }) async {
    final uri = _buildChatUri(baseUrl);
    final body = jsonEncode({
      'model': modelName.trim(),
      'messages': [
        {
          'role': 'system',
          'content': SeedData.economicModelGeneratorSystemPrompt,
        },
        {
          'role': 'user',
          'content': '请为以下主题生成完整的经济学统计对比模型 JSON：$topic',
        },
      ],
      'temperature': 0.3,
      'stream': false,
    });

    final response = await http
        .post(uri, headers: _headers(apiKey), body: body)
        .timeout(const Duration(seconds: 90));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = decoded['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('模型未返回有效内容');
    }
    var content =
        (choices.first as Map)['message']?['content']?.toString().trim() ?? '';

    // Strip markdown code fences if a model accidentally adds them
    content = _extractJsonObject(content);
    final jsonMap = jsonDecode(content) as Map<String, dynamic>;
    return parseGeneratedEconomicJson(jsonMap);
  }

  static String _extractJsonObject(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      final firstNewline = cleaned.indexOf('\n');
      if (firstNewline != -1) {
        cleaned = cleaned.substring(firstNewline + 1);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();
    }
    final startIdx = cleaned.indexOf('{');
    final endIdx = cleaned.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      return cleaned.substring(startIdx, endIdx + 1);
    }
    return cleaned;
  }

  static GeneratedEconomicModel parseGeneratedEconomicJson(
    Map<String, dynamic> jsonMap,
  ) {
    final name = (jsonMap['name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      throw const FormatException('返回 JSON 缺少有效的指标名称 (name)');
    }
    final description = (jsonMap['description'] as String?)?.trim() ?? '';
    final denomType = (jsonMap['denominator_type'] as String?) == 'manual_base'
        ? 'manual_base'
        : 'total_expense';
    final keywords = ((jsonMap['suggested_category_keywords'] as List?) ?? [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final metricId = 'metric_${_uuid.v4()}';
    final now = DateTime.now().millisecondsSinceEpoch;
    final metric = EconomicMetric(
      id: metricId,
      name: name,
      description: description,
      denominatorType: denomType,
      suggestedCategoryKeywords: keywords,
      isBuiltin: false,
      updatedAt: now,
    );

    final benchmarks = <EconomicBenchmark>[];

    final rawTiers = (jsonMap['tier_standards'] as List?) ?? [];
    for (final item in rawTiers) {
      if (item is! Map) continue;
      final tName = item['name']?.toString().trim() ?? '';
      final val = (item['value'] as num?)?.toDouble();
      final maxVal = (item['max_value'] as num?)?.toDouble();
      if (tName.isEmpty || val == null) continue;
      benchmarks.add(
        EconomicBenchmark(
          id: 'bench_${_uuid.v4()}',
          metricId: metricId,
          name: tName,
          isTierStandard: true,
          value: val.clamp(0.0, 100.0),
          maxValue: (maxVal ?? 100.0).clamp(0.0, 100.0),
          note: item['note']?.toString().trim() ?? '',
        ),
      );
    }

    final rawSamples = (jsonMap['benchmarks'] as List?) ?? [];
    for (final item in rawSamples) {
      if (item is! Map) continue;
      final bName = item['name']?.toString().trim() ?? '';
      final val = (item['value'] as num?)?.toDouble();
      if (bName.isEmpty || val == null) continue;
      benchmarks.add(
        EconomicBenchmark(
          id: 'bench_${_uuid.v4()}',
          metricId: metricId,
          name: bName,
          isTierStandard: false,
          value: double.parse(val.clamp(0.0, 100.0).toStringAsFixed(2)),
          maxValue: null,
          note: item['note']?.toString().trim() ?? '',
        ),
      );
    }

    if (benchmarks.where((b) => !b.isTierStandard).isEmpty) {
      throw const FormatException('返回 JSON 未包含有效的对比样本数据 (benchmarks)');
    }

    return GeneratedEconomicModel(metric: metric, benchmarks: benchmarks);
  }
}
