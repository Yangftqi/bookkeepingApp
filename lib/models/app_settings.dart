import 'ai_models.dart';

class AppSettings {
  final String? masterPinHash;
  final String? masterPinSalt;
  final String currencySymbol;
  final List<LlmProfile> llmProfiles;
  final String? activeLlmProfileId;
  final List<AiRolePreset> aiRolePresets;
  final String? currentActiveUserId;

  const AppSettings({
    this.masterPinHash,
    this.masterPinSalt,
    this.currencySymbol = '¥',
    this.llmProfiles = const [LlmProfile.defaultProfile],
    this.activeLlmProfileId = 'default_llm_profile',
    this.aiRolePresets = const [],
    this.currentActiveUserId,
  });

  LlmProfile get activeLlmProfile {
    if (llmProfiles.isEmpty) return LlmProfile.defaultProfile;
    for (final p in llmProfiles) {
      if (p.id == activeLlmProfileId) return p;
    }
    return llmProfiles.first;
  }

  String get llmBaseUrl => activeLlmProfile.baseUrl;
  String get llmApiKey => activeLlmProfile.apiKey;
  String get llmModelName => activeLlmProfile.modelName;
  LlmApiFormat get llmApiFormat => activeLlmProfile.apiFormat;

  bool get hasMasterPin =>
      masterPinHash != null &&
      masterPinHash!.isNotEmpty &&
      masterPinSalt != null &&
      masterPinSalt!.isNotEmpty;

  String get displayCurrency => currencySymbol == '无符号' ? '' : currencySymbol;

  AppSettings copyWith({
    String? masterPinHash,
    String? masterPinSalt,
    String? currencySymbol,
    List<LlmProfile>? llmProfiles,
    String? activeLlmProfileId,
    List<AiRolePreset>? aiRolePresets,
    String? currentActiveUserId,
  }) {
    return AppSettings(
      masterPinHash: masterPinHash ?? this.masterPinHash,
      masterPinSalt: masterPinSalt ?? this.masterPinSalt,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      llmProfiles: llmProfiles ?? this.llmProfiles,
      activeLlmProfileId: activeLlmProfileId ?? this.activeLlmProfileId,
      aiRolePresets: aiRolePresets ?? this.aiRolePresets,
      currentActiveUserId: currentActiveUserId ?? this.currentActiveUserId,
    );
  }

  Map<String, dynamic> toBackupJson() => {
        'master_pin_hash': masterPinHash,
        'master_pin_salt': masterPinSalt,
        'currency_symbol': currencySymbol,
        'llm_base_url': llmBaseUrl,
        'llm_api_key': llmApiKey,
        'llm_model_name': llmModelName,
        'llm_profiles': llmProfiles.map((e) => e.toJson()).toList(),
        'active_llm_profile_id': activeLlmProfile.id,
        'ai_role_presets': aiRolePresets.map((e) => e.toJson()).toList(),
        'current_active_user_id': currentActiveUserId,
      };
}
