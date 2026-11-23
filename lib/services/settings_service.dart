import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/seed_data.dart';
import '../models/ai_models.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const _kMasterPinHash = 'master_pin_hash';
  static const _kMasterPinSalt = 'master_pin_salt';
  static const _kCurrencySymbol = 'currency_symbol';
  static const _kLlmBaseUrl = 'llm_base_url';
  static const _kLlmApiKey = 'llm_api_key';
  static const _kLlmModelName = 'llm_model_name';
  static const _kLlmProfilesJson = 'llm_profiles_json';
  static const _kActiveLlmProfileId = 'active_llm_profile_id';
  static const _kAiRolePresets = 'ai_role_presets_json';
  static const _kAiRolePresetsVersion = 'ai_role_presets_version';
  static const _kCurrentActiveUserId = 'current_active_user_id';

  static const int _currentPresetsVersion = 2;

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final builtinDefaults = SeedData.defaultAiRolePresets();
    final builtinById = {for (final b in builtinDefaults) b.id: b};

    List<AiRolePreset> presets = builtinDefaults;
    final rawPresets = prefs.getString(_kAiRolePresets);
    final savedVer = prefs.getInt(_kAiRolePresetsVersion) ?? 1;

    if (rawPresets != null && rawPresets.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPresets) as List;
        final parsed = decoded
            .map((e) => AiRolePreset.fromJson((e as Map).cast<String, dynamic>()))
            .map((p) {
              if (p.tagline.isEmpty && builtinById.containsKey(p.id)) {
                return p.copyWith(tagline: builtinById[p.id]!.tagline);
              }
              return p;
            })
            .toList();

        if (parsed.isNotEmpty) {
          if (savedVer < _currentPresetsVersion) {
            final existingIds = parsed.map((p) => p.id).toSet();
            for (final b in builtinDefaults) {
              if (!existingIds.contains(b.id)) {
                parsed.add(b);
              }
            }
            await prefs.setInt(_kAiRolePresetsVersion, _currentPresetsVersion);
            await prefs.setString(
              _kAiRolePresets,
              jsonEncode(parsed.map((e) => e.toJson()).toList()),
            );
          }
          presets = parsed;
        }
      } catch (_) {}
    } else {
      await prefs.setInt(_kAiRolePresetsVersion, _currentPresetsVersion);
    }

    // Load multi-profile LLM configurations (with seamless migration from v1 single config)
    List<LlmProfile> llmProfiles = const [LlmProfile.defaultProfile];
    String? activeProfileId = prefs.getString(_kActiveLlmProfileId);
    final rawProfiles = prefs.getString(_kLlmProfilesJson);
    if (rawProfiles != null && rawProfiles.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawProfiles) as List;
        final parsed = decoded
            .map((e) => LlmProfile.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        if (parsed.isNotEmpty) {
          llmProfiles = parsed;
        }
      } catch (_) {}
    } else {
      final legacyBase = prefs.getString(_kLlmBaseUrl);
      final legacyKey = prefs.getString(_kLlmApiKey);
      final legacyModel = prefs.getString(_kLlmModelName);
      if (legacyBase != null || legacyKey != null || legacyModel != null) {
        llmProfiles = [
          LlmProfile(
            id: 'default_llm_profile',
            name: '默认配置',
            apiFormat: LlmApiFormat.openaiCompatible,
            baseUrl: legacyBase ?? 'https://api.deepseek.com/v1',
            apiKey: legacyKey ?? '',
            modelName: legacyModel ?? 'deepseek-chat',
          ),
        ];
        activeProfileId = 'default_llm_profile';
      }
    }

    if (activeProfileId == null ||
        !llmProfiles.any((p) => p.id == activeProfileId)) {
      activeProfileId = llmProfiles.first.id;
    }

    return AppSettings(
      masterPinHash: prefs.getString(_kMasterPinHash),
      masterPinSalt: prefs.getString(_kMasterPinSalt),
      currencySymbol: prefs.getString(_kCurrencySymbol) ?? '¥',
      llmProfiles: llmProfiles,
      activeLlmProfileId: activeProfileId,
      aiRolePresets: presets,
      currentActiveUserId: prefs.getString(_kCurrentActiveUserId),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (settings.masterPinHash != null) {
      await prefs.setString(_kMasterPinHash, settings.masterPinHash!);
    }
    if (settings.masterPinSalt != null) {
      await prefs.setString(_kMasterPinSalt, settings.masterPinSalt!);
    }
    await prefs.setString(_kCurrencySymbol, settings.currencySymbol);
    await prefs.setString(
      _kLlmProfilesJson,
      jsonEncode(settings.llmProfiles.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(_kActiveLlmProfileId, settings.activeLlmProfile.id);
    // Keep legacy keys in sync for safety
    await prefs.setString(_kLlmBaseUrl, settings.llmBaseUrl);
    await prefs.setString(_kLlmApiKey, settings.llmApiKey);
    await prefs.setString(_kLlmModelName, settings.llmModelName);
    await prefs.setString(
      _kAiRolePresets,
      jsonEncode(settings.aiRolePresets.map((e) => e.toJson()).toList()),
    );
    await prefs.setInt(_kAiRolePresetsVersion, _currentPresetsVersion);
    if (settings.currentActiveUserId != null) {
      await prefs.setString(
        _kCurrentActiveUserId,
        settings.currentActiveUserId!,
      );
    } else {
      await prefs.remove(_kCurrentActiveUserId);
    }
  }
}
