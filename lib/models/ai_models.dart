enum LlmApiFormat {
  openaiCompatible,
  gemini,
  claude,
}

extension LlmApiFormatExt on LlmApiFormat {
  String get wireValue {
    switch (this) {
      case LlmApiFormat.openaiCompatible:
        return 'openai_compatible';
      case LlmApiFormat.gemini:
        return 'gemini';
      case LlmApiFormat.claude:
        return 'claude';
    }
  }

  String get displayName {
    switch (this) {
      case LlmApiFormat.openaiCompatible:
        return 'OpenAI 兼容格式';
      case LlmApiFormat.gemini:
        return 'Google Gemini 原生格式';
      case LlmApiFormat.claude:
        return 'Anthropic Claude 原生格式';
    }
  }

  String get shortBadge {
    switch (this) {
      case LlmApiFormat.openaiCompatible:
        return 'OpenAI 兼容';
      case LlmApiFormat.gemini:
        return 'Gemini 原生';
      case LlmApiFormat.claude:
        return 'Claude 原生';
    }
  }

  String get providersHint {
    switch (this) {
      case LlmApiFormat.openaiCompatible:
        return '适用：OpenAI、DeepSeek、通义千问、硅基流动、智谱、Kimi、OpenRouter、Ollama 等';
      case LlmApiFormat.gemini:
        return '适用：Google AI Studio / Gemini 官方原生接口及原生中转站';
      case LlmApiFormat.claude:
        return '适用：Anthropic Claude 官方接口及 Claude 原生中转站';
    }
  }

  String get defaultBaseUrl {
    switch (this) {
      case LlmApiFormat.openaiCompatible:
        return 'https://api.deepseek.com/v1';
      case LlmApiFormat.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta';
      case LlmApiFormat.claude:
        return 'https://api.anthropic.com/v1';
    }
  }

  String get defaultModel {
    switch (this) {
      case LlmApiFormat.openaiCompatible:
        return 'deepseek-chat';
      case LlmApiFormat.gemini:
        return 'gemini-2.5-flash';
      case LlmApiFormat.claude:
        return 'claude-sonnet-4-20250514';
    }
  }

  List<Map<String, String>> get quickBaseUrls {
    switch (this) {
      case LlmApiFormat.openaiCompatible:
        return const [
          {'label': 'DeepSeek 官方', 'url': 'https://api.deepseek.com/v1'},
          {'label': 'OpenAI 官方', 'url': 'https://api.openai.com/v1'},
          {'label': '通义千问 (DashScope)', 'url': 'https://dashscope.aliyuncs.com/compatible-mode/v1'},
          {'label': '硅基流动 (SiliconFlow)', 'url': 'https://api.siliconflow.cn/v1'},
          {'label': 'OpenRouter', 'url': 'https://openrouter.ai/api/v1'},
          {'label': 'Google Gemini (OpenAI兼容)', 'url': 'https://generativelanguage.googleapis.com/v1beta/openai'},
          {'label': '本地 Ollama', 'url': 'http://127.0.0.1:11434/v1'},
        ];
      case LlmApiFormat.gemini:
        return const [
          {'label': 'Google AI Studio 官方', 'url': 'https://generativelanguage.googleapis.com/v1beta'},
        ];
      case LlmApiFormat.claude:
        return const [
          {'label': 'Anthropic 官方', 'url': 'https://api.anthropic.com/v1'},
        ];
    }
  }

  static LlmApiFormat fromWire(String? value) {
    switch (value) {
      case 'gemini':
        return LlmApiFormat.gemini;
      case 'claude':
        return LlmApiFormat.claude;
      case 'openai_compatible':
      default:
        return LlmApiFormat.openaiCompatible;
    }
  }
}

class LlmProfile {
  final String id;
  final String name;
  final LlmApiFormat apiFormat;
  final String baseUrl;
  final String apiKey;
  final String modelName;

  const LlmProfile({
    required this.id,
    required this.name,
    this.apiFormat = LlmApiFormat.openaiCompatible,
    required this.baseUrl,
    this.apiKey = '',
    required this.modelName,
  });

  static const LlmProfile defaultProfile = LlmProfile(
    id: 'default_llm_profile',
    name: '默认配置',
    apiFormat: LlmApiFormat.openaiCompatible,
    baseUrl: 'https://api.deepseek.com/v1',
    apiKey: '',
    modelName: 'deepseek-chat',
  );

  LlmProfile copyWith({
    String? id,
    String? name,
    LlmApiFormat? apiFormat,
    String? baseUrl,
    String? apiKey,
    String? modelName,
  }) {
    return LlmProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      apiFormat: apiFormat ?? this.apiFormat,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'apiFormat': apiFormat.wireValue,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'modelName': modelName,
      };

  factory LlmProfile.fromJson(Map<String, dynamic> json) {
    return LlmProfile(
      id: (json['id'] as String?) ?? 'default_llm_profile',
      name: (json['name'] as String?) ?? '默认配置',
      apiFormat: LlmApiFormatExt.fromWire(json['apiFormat'] as String?),
      baseUrl: (json['baseUrl'] as String?) ?? 'https://api.deepseek.com/v1',
      apiKey: (json['apiKey'] as String?) ?? '',
      modelName: (json['modelName'] as String?) ?? 'deepseek-chat',
    );
  }
}

class AiRolePreset {
  final String id;
  final String name;
  final String tagline;
  final String systemPrompt;
  final bool isBuiltin;

  const AiRolePreset({
    required this.id,
    required this.name,
    this.tagline = '',
    required this.systemPrompt,
    required this.isBuiltin,
  });

  /// Returns [tagline] if provided; otherwise falls back to a single-line preview of [systemPrompt].
  String get displayTagline {
    final t = tagline.trim();
    if (t.isNotEmpty) return t;
    return systemPrompt.replaceAll('\n', ' ').trim();
  }

  AiRolePreset copyWith({
    String? id,
    String? name,
    String? tagline,
    String? systemPrompt,
    bool? isBuiltin,
  }) {
    return AiRolePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      tagline: tagline ?? this.tagline,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      isBuiltin: isBuiltin ?? this.isBuiltin,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tagline': tagline,
        'systemPrompt': systemPrompt,
        'isBuiltin': isBuiltin,
      };

  factory AiRolePreset.fromJson(Map<String, dynamic> json) {
    return AiRolePreset(
      id: json['id'] as String,
      name: json['name'] as String,
      tagline: (json['tagline'] as String?) ?? '',
      systemPrompt: json['systemPrompt'] as String,
      isBuiltin: json['isBuiltin'] as bool? ?? false,
    );
  }
}

class AiChatSession {
  final String id;
  final String userId;
  final String title;
  final String rolePresetId;
  final String contextSummaryJson;
  final int createdAt;

  const AiChatSession({
    required this.id,
    required this.userId,
    required this.title,
    required this.rolePresetId,
    required this.contextSummaryJson,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'role_preset_id': rolePresetId,
        'context_summary_json': contextSummaryJson,
        'created_at': createdAt,
      };

  factory AiChatSession.fromMap(Map<String, dynamic> map) {
    return AiChatSession(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      rolePresetId: map['role_preset_id'] as String,
      contextSummaryJson: (map['context_summary_json'] as String?) ?? '{}',
      createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
    );
  }
}

class AiChatMessage {
  final String id;
  final String sessionId;
  final String role; // 'system' | 'user' | 'assistant'
  final String content;
  final int createdAt;

  const AiChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  AiChatMessage copyWith({
    String? id,
    String? sessionId,
    String? role,
    String? content,
    int? createdAt,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'role': role,
        'content': content,
        'created_at': createdAt,
      };

  factory AiChatMessage.fromMap(Map<String, dynamic> map) {
    return AiChatMessage(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
    );
  }
}
