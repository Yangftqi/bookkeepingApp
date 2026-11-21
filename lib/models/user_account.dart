class UserAccount {
  final String id;
  final String name;

  /// 0: 无 (打开即用)
  /// 1: 删改
  /// 2: 增删改
  /// 3: 增删改查
  final int authLevel;
  final String? pinHash;
  final String? pinSalt;
  final String activeThemeId;
  final int createdAt;

  const UserAccount({
    required this.id,
    required this.name,
    required this.authLevel,
    this.pinHash,
    this.pinSalt,
    required this.activeThemeId,
    required this.createdAt,
  });

  String get authLevelLabel {
    switch (authLevel) {
      case 0:
        return '无密码';
      case 1:
        return '删改保护';
      case 2:
        return '增删改保护';
      case 3:
        return '增删改查全保护';
      default:
        return '无密码';
    }
  }

  UserAccount copyWith({
    String? id,
    String? name,
    int? authLevel,
    String? pinHash,
    String? pinSalt,
    bool clearPin = false,
    String? activeThemeId,
    int? createdAt,
  }) {
    return UserAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      authLevel: authLevel ?? this.authLevel,
      pinHash: clearPin ? null : (pinHash ?? this.pinHash),
      pinSalt: clearPin ? null : (pinSalt ?? this.pinSalt),
      activeThemeId: activeThemeId ?? this.activeThemeId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'auth_level': authLevel,
      'pin_hash': pinHash,
      'pin_salt': pinSalt,
      'active_theme_id': activeThemeId,
      'created_at': createdAt,
    };
  }

  factory UserAccount.fromMap(Map<String, dynamic> map) {
    return UserAccount(
      id: map['id'] as String,
      name: map['name'] as String,
      authLevel: (map['auth_level'] as num?)?.toInt() ?? 0,
      pinHash: map['pin_hash'] as String?,
      pinSalt: map['pin_salt'] as String?,
      activeThemeId: map['active_theme_id'] as String? ?? 'builtin_theme_light',
      createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
    );
  }
}
