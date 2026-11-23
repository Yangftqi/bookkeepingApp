import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../data/seed_data.dart';
import '../models/ai_models.dart';
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

  static String _trimBase(String baseUrl) {
    var trimmed = baseUrl.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static Uri _buildOpenAiChatUri(String baseUrl) {
    final base = _trimBase(baseUrl);
    if (base.endsWith('/chat/completions')) return Uri.parse(base);
    return Uri.parse('$base/chat/completions');
  }

  static Uri _buildOpenAiModelsUri(String baseUrl) {
    var base = _trimBase(baseUrl);
    if (base.endsWith('/chat/completions')) {
      base = base.substring(0, base.length - '/chat/completions'.length);
    }
    if (base.endsWith('/models')) return Uri.parse(base);
    return Uri.parse('$base/models');
  }

  static Uri _buildGeminiModelsUri(String baseUrl, String apiKey) {
    final base = _trimBase(baseUrl);
    final raw = base.endsWith('/models') ? base : '$base/models';
    final uri = Uri.parse(raw);
    final params = Map<String, String>.from(uri.queryParameters);
    params['pageSize'] = '200';
    if (apiKey.trim().isNotEmpty) {
      params['key'] = apiKey.trim();
    }
    return uri.replace(queryParameters: params);
  }

  static Uri _buildGeminiGenerateUri(
    String baseUrl,
    String modelName,
    String apiKey, {
    required bool stream,
  }) {
    final base = _trimBase(baseUrl);
    final cleanModel = modelName.trim().startsWith('models/')
        ? modelName.trim().substring('models/'.length)
        : modelName.trim();
    final method = stream ? 'streamGenerateContent' : 'generateContent';
    final uri = Uri.parse('$base/models/$cleanModel:$method');
    final params = Map<String, String>.from(uri.queryParameters);
    if (stream) params['alt'] = 'sse';
    if (apiKey.trim().isNotEmpty) params['key'] = apiKey.trim();
    return uri.replace(queryParameters: params);
  }

  static Uri _buildClaudeMessagesUri(String baseUrl) {
    final base = _trimBase(baseUrl);
    if (base.endsWith('/messages')) return Uri.parse(base);
    return Uri.parse('$base/messages');
  }

  static Uri _buildClaudeModelsUri(String baseUrl) {
    var base = _trimBase(baseUrl);
    if (base.endsWith('/messages')) {
      base = base.substring(0, base.length - '/messages'.length);
    }
    if (base.endsWith('/models')) return Uri.parse(base);
    return Uri.parse('$base/models');
  }

  static Map<String, String> _openAiHeaders(String apiKey) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream, application/json',
    };
    if (apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }
    return headers;
  }

  static Map<String, String> _geminiHeaders(String apiKey) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream, application/json',
    };
    if (apiKey.trim().isNotEmpty) {
      headers['x-goog-api-key'] = apiKey.trim();
    }
    return headers;
  }

  static Map<String, String> _claudeHeaders(String apiKey) {
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream, application/json',
      'anthropic-version': '2023-06-01',
      if (apiKey.trim().isNotEmpty) 'x-api-key': apiKey.trim(),
    };
  }

  /// Queries the provider's native `/models` endpoint and returns available model IDs.
  static Future<List<String>> fetchModels({
    required LlmApiFormat apiFormat,
    required String baseUrl,
    required String apiKey,
  }) async {
    if (baseUrl.trim().isEmpty) {
      throw ArgumentError('请先填写 Base URL');
    }

    late Uri uri;
    late Map<String, String> headers;
    switch (apiFormat) {
      case LlmApiFormat.openaiCompatible:
        uri = _buildOpenAiModelsUri(baseUrl);
        headers = _openAiHeaders(apiKey);
        break;
      case LlmApiFormat.gemini:
        uri = _buildGeminiModelsUri(baseUrl, apiKey);
        headers = _geminiHeaders(apiKey);
        break;
      case LlmApiFormat.claude:
        uri = _buildClaudeModelsUri(baseUrl);
        headers = _claudeHeaders(apiKey);
        break;
    }

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 25));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final models = parseModelListResponse(apiFormat, decoded);
    if (models.isEmpty) {
      throw Exception('接口返回成功，但未解析到可用模型列表，请尝试手动填写模型名称');
    }
    return models;
  }

  static List<String> parseModelListResponse(
    LlmApiFormat apiFormat,
    dynamic decoded,
  ) {
    final result = <String>{};

    if (apiFormat == LlmApiFormat.gemini && decoded is Map) {
      final list = decoded['models'] as List? ?? const [];
      for (final item in list) {
        if (item is! Map) continue;
        final methods =
            (item['supportedGenerationMethods'] as List?)?.cast<dynamic>() ??
                const [];
        if (methods.isNotEmpty && !methods.contains('generateContent')) {
          continue;
        }
        var name = item['name']?.toString().trim() ?? '';
        if (name.startsWith('models/')) {
          name = name.substring('models/'.length);
        }
        if (name.isNotEmpty) result.add(name);
      }
    } else if (decoded is Map) {
      final list =
          (decoded['data'] as List?) ?? (decoded['models'] as List?) ?? const [];
      for (final item in list) {
        if (item is Map) {
          final id = (item['id'] ?? item['name'])?.toString().trim() ?? '';
          if (id.isNotEmpty) result.add(id);
        } else if (item is String && item.trim().isNotEmpty) {
          result.add(item.trim());
        }
      }
    } else if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          final id = (item['id'] ?? item['name'])?.toString().trim() ?? '';
          if (id.isNotEmpty) result.add(id);
        } else if (item is String && item.trim().isNotEmpty) {
          result.add(item.trim());
        }
      }
    }

    final sorted = result.toList()..sort();
    return sorted;
  }

  /// Tests connectivity using the selected native protocol.
  static Future<String> testConnection({
    required LlmApiFormat apiFormat,
    required String baseUrl,
    required String apiKey,
    required String modelName,
  }) async {
    final text = await _sendSingleCompletion(
      apiFormat: apiFormat,
      baseUrl: baseUrl,
      apiKey: apiKey,
      modelName: modelName,
      messages: const [
        {'role': 'user', 'content': '请回复“连接成功”四个字。'},
      ],
      maxTokens: 64,
    );
    return text.isEmpty ? '连接成功' : text;
  }

  static Future<String> _sendSingleCompletion({
    required LlmApiFormat apiFormat,
    required String baseUrl,
    required String apiKey,
    required String modelName,
    required List<Map<String, String>> messages,
    int maxTokens = 4096,
    double? temperature,
  }) async {
    switch (apiFormat) {
      case LlmApiFormat.openaiCompatible:
        final uri = _buildOpenAiChatUri(baseUrl);
        final payload = <String, dynamic>{
          'model': modelName.trim(),
          'messages': messages,
          'max_tokens': maxTokens,
          'stream': false,
          if (temperature != null) 'temperature': temperature,
        };
        final resp = await http
            .post(
              uri,
              headers: _openAiHeaders(apiKey),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 90));
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
        }
        final decoded =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final choices = decoded['choices'] as List?;
        if (choices == null || choices.isEmpty) return '';
        return (choices.first as Map)['message']?['content']
                ?.toString()
                .trim() ??
            '';

      case LlmApiFormat.gemini:
        final uri = _buildGeminiGenerateUri(
          baseUrl,
          modelName,
          apiKey,
          stream: false,
        );
        final payload = _buildGeminiBody(
          messages,
          maxTokens: maxTokens,
          temperature: temperature,
        );
        final resp = await http
            .post(
              uri,
              headers: _geminiHeaders(apiKey),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 90));
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
        }
        final decoded =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        return _extractGeminiCandidateText(decoded).trim();

      case LlmApiFormat.claude:
        final uri = _buildClaudeMessagesUri(baseUrl);
        final payload = _buildClaudeBody(
          modelName,
          messages,
          stream: false,
          maxTokens: maxTokens,
          temperature: temperature,
        );
        final resp = await http
            .post(
              uri,
              headers: _claudeHeaders(apiKey),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 90));
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
        }
        final decoded =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final contentList = decoded['content'] as List? ?? const [];
        final sb = StringBuffer();
        for (final block in contentList) {
          if (block is Map && block['type'] == 'text') {
            sb.write(block['text'] ?? '');
          }
        }
        return sb.toString().trim();
    }
  }

  static Map<String, dynamic> _buildGeminiBody(
    List<Map<String, String>> messages, {
    int? maxTokens,
    double? temperature,
  }) {
    final systemParts = <String>[];
    final contents = <Map<String, dynamic>>[];
    for (final m in messages) {
      final role = m['role'] ?? 'user';
      final text = m['content'] ?? '';
      if (role == 'system') {
        if (text.isNotEmpty) systemParts.add(text);
      } else {
        contents.add({
          'role': role == 'assistant' ? 'model' : 'user',
          'parts': [
            {'text': text},
          ],
        });
      }
    }
    return {
      if (systemParts.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemParts.join('\n\n')},
          ],
        },
      'contents': contents,
      'generationConfig': {
        if (maxTokens != null) 'maxOutputTokens': maxTokens,
        if (temperature != null) 'temperature': temperature,
      },
    };
  }

  static String _extractGeminiCandidateText(Map<String, dynamic> jsonObj) {
    final candidates = jsonObj['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';
    final content = (candidates.first as Map)['content'] as Map?;
    final parts = content?['parts'] as List?;
    if (parts == null) return '';
    final sb = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['text'] != null) {
        sb.write(part['text'].toString());
      }
    }
    return sb.toString();
  }

  static Map<String, dynamic> _buildClaudeBody(
    String modelName,
    List<Map<String, String>> messages, {
    required bool stream,
    int maxTokens = 4096,
    double? temperature,
  }) {
    final systemParts = <String>[];
    final chatMsgs = <Map<String, String>>[];
    for (final m in messages) {
      final role = m['role'] ?? 'user';
      final text = m['content'] ?? '';
      if (role == 'system') {
        if (text.isNotEmpty) systemParts.add(text);
      } else {
        chatMsgs.add({
          'role': role == 'assistant' ? 'assistant' : 'user',
          'content': text,
        });
      }
    }
    return {
      'model': modelName.trim(),
      'max_tokens': maxTokens,
      'stream': stream,
      if (systemParts.isNotEmpty) 'system': systemParts.join('\n\n'),
      if (temperature != null) 'temperature': temperature,
      'messages': chatMsgs,
    };
  }

  /// Streams delta content tokens across OpenAI-compatible, Gemini native, and Claude native protocols.
  static Stream<String> streamChat({
    required LlmProfile profile,
    required List<Map<String, String>> messages,
  }) async* {
    final client = http.Client();
    try {
      late http.Request request;
      switch (profile.apiFormat) {
        case LlmApiFormat.openaiCompatible:
          request = http.Request('POST', _buildOpenAiChatUri(profile.baseUrl));
          request.headers.addAll(_openAiHeaders(profile.apiKey));
          request.body = jsonEncode({
            'model': profile.modelName.trim(),
            'messages': messages,
            'stream': true,
          });
          break;

        case LlmApiFormat.gemini:
          request = http.Request(
            'POST',
            _buildGeminiGenerateUri(
              profile.baseUrl,
              profile.modelName,
              profile.apiKey,
              stream: true,
            ),
          );
          request.headers.addAll(_geminiHeaders(profile.apiKey));
          request.body = jsonEncode(_buildGeminiBody(messages));
          break;

        case LlmApiFormat.claude:
          request =
              http.Request('POST', _buildClaudeMessagesUri(profile.baseUrl));
          request.headers.addAll(_claudeHeaders(profile.apiKey));
          request.body = jsonEncode(
            _buildClaudeBody(profile.modelName, messages, stream: true),
          );
          break;
      }

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
          switch (profile.apiFormat) {
            case LlmApiFormat.openaiCompatible:
              final choices = jsonObj['choices'] as List?;
              if (choices == null || choices.isEmpty) continue;
              final delta = (choices.first as Map)['delta'] as Map?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) yield content;
              break;

            case LlmApiFormat.gemini:
              final text = _extractGeminiCandidateText(jsonObj);
              if (text.isNotEmpty) yield text;
              break;

            case LlmApiFormat.claude:
              if (jsonObj['type'] == 'content_block_delta') {
                final delta = jsonObj['delta'] as Map?;
                final text = delta?['text'] as String?;
                if (text != null && text.isNotEmpty) yield text;
              } else if (jsonObj['type'] == 'message_stop') {
                return;
              }
              break;
          }
        } catch (_) {
          // Ignore keepalive or partial metadata frames
        }
      }
    } finally {
      client.close();
    }
  }

  /// Engine 1: Uses the active LLM profile (any of the 3 native protocols)
  /// with Appendix B.2 strict JSON Schema prompt to generate an economic model.
  static Future<GeneratedEconomicModel> generateEconomicModel({
    required LlmProfile profile,
    required String topic,
  }) async {
    var content = await _sendSingleCompletion(
      apiFormat: profile.apiFormat,
      baseUrl: profile.baseUrl,
      apiKey: profile.apiKey,
      modelName: profile.modelName,
      messages: [
        {
          'role': 'system',
          'content': SeedData.economicModelGeneratorSystemPrompt,
        },
        {
          'role': 'user',
          'content': '请为以下主题生成完整的经济学统计对比模型 JSON：$topic',
        },
      ],
      temperature: 0.3,
    );

    if (content.isEmpty) {
      throw Exception('模型未返回有效内容');
    }

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
