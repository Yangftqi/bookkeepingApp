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
