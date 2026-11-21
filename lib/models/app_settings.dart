import 'ai_models.dart';

class AppSettings {
  final String? masterPinHash;
  final String? masterPinSalt;
  final String currencySymbol;
  final String llmBaseUrl;
  final String llmApiKey;
  final String llmModelName;
  final List<AiRolePreset> aiRolePresets;
  final String? currentActiveUserId;

  const AppSettings({
    this.masterPinHash,
    this.masterPinSalt,
    this.currencySymbol = '¥',
    this.llmBaseUrl = 'https://api.deepseek.com/v1',
    this.llmApiKey = '',
    this.llmModelName = 'deepseek-chat',
    this.aiRolePresets = const [],
    this.currentActiveUserId,
  });

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
    String? llmBaseUrl,
    String? llmApiKey,
    String? llmModelName,
    List<AiRolePreset>? aiRolePresets,
    String? currentActiveUserId,
  }) {
    return AppSettings(
      masterPinHash: masterPinHash ?? this.masterPinHash,
      masterPinSalt: masterPinSalt ?? this.masterPinSalt,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      llmBaseUrl: llmBaseUrl ?? this.llmBaseUrl,
      llmApiKey: llmApiKey ?? this.llmApiKey,
      llmModelName: llmModelName ?? this.llmModelName,
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
        'ai_role_presets': aiRolePresets.map((e) => e.toJson()).toList(),
        'current_active_user_id': currentActiveUserId,
      };
}
