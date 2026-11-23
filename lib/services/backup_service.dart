import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../data/db/app_database.dart';
import '../models/ai_models.dart';
import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/economic_models.dart';
import '../models/expense.dart';
import '../models/theme_config.dart';
import '../models/user_account.dart';
import '../utils/color_utils.dart';
import 'image_service.dart';
import 'settings_service.dart';

enum UserImportConflictMode { mergeByUuid, overwriteExisting, importAsNewUser }

class UserPackageInspection {
  final String filePath;
  final Map<String, dynamic> manifest;
  final UserAccount? existingSameNameUser;
  final int expenseCount;
  final bool hasAiSessions;
  final bool hasGlobalExtras;

  const UserPackageInspection({
    required this.filePath,
    required this.manifest,
    this.existingSameNameUser,
    required this.expenseCount,
    required this.hasAiSessions,
    required this.hasGlobalExtras,
  });
}

class ThemePackageInspection {
  final String filePath;
  final String themeName;
  final List<String> missingCategoryNames;
  final Map<String, String> missingCategoryDefaultColors;

  const ThemePackageInspection({
    required this.filePath,
    required this.themeName,
    required this.missingCategoryNames,
    required this.missingCategoryDefaultColors,
  });
}

class BackupService {
  static const _uuid = Uuid();

  static Future<Directory> _exportDir() async {
    final dir = await getTemporaryDirectory();
    final out = Directory(p.join(dir.path, 'jimi_exports'));
    if (!await out.exists()) {
      await out.create(recursive: true);
    }
    return out;
  }

  static void _addJsonFile(Archive archive, String path, Object data) {
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  static Map<String, dynamic>? _readJsonMap(Archive archive, String name) {
    final file = archive.findFile(name);
    if (file == null) return null;
    final content = utf8.decode(file.content as List<int>);
    return jsonDecode(content) as Map<String, dynamic>;
  }

  static List<dynamic>? _readJsonList(Archive archive, String name) {
    final file = archive.findFile(name);
    if (file == null) return null;
    final content = utf8.decode(file.content as List<int>);
    return jsonDecode(content) as List<dynamic>;
  }

  // =========================================================================
  // 1. SINGLE USER PACKAGE (.userpkg.zip)
  // =========================================================================

  static Future<String> exportUserPackage({
    required UserAccount user,
    required bool includeAiSessions,
    required bool includeGlobalExtras,
    required AppSettings settings,
  }) async {
    final db = AppDatabase.instance;
    final expenses = await db.getExpensesForUser(user.id);
    final dayOverrides = await db.getDayOverridesForUser(user.id);
    final allCategories = await db.getCategories();
    final usedCatIds = expenses.map((e) => e.categoryId).toSet();
    final usedCategories = allCategories
        .where((c) => usedCatIds.contains(c.id) || c.isUncategorized)
        .toList();

    final archive = Archive();
    _addJsonFile(archive, 'manifest.json', {
      'package_type': 'user_package',
      'version': 1,
      'exported_at': DateTime.now().millisecondsSinceEpoch,
      'user': {
        'id': user.id,
        'name': user.name,
        'auth_level': user.authLevel,
        'active_theme_id': user.activeThemeId,
      },
      'expense_count': expenses.length,
      'has_ai_sessions': includeAiSessions,
      'has_global_extras': includeGlobalExtras,
    });
    _addJsonFile(
      archive,
      'categories.json',
      usedCategories.map((c) => c.toMap()).toList(),
    );
    _addJsonFile(
      archive,
      'expenses.json',
      expenses.map((e) => e.toMap()).toList(),
    );
    _addJsonFile(
      archive,
      'user_day_overrides.json',
      dayOverrides.entries
          .map(
            (e) => {
              'user_id': user.id,
              'date_str': e.key,
              'is_rest_day': e.value ? 1 : 0,
            },
          )
          .toList(),
    );

    if (includeAiSessions) {
      final sessions = await db.getAiSessionsForUser(user.id);
      final sessionsData = <Map<String, dynamic>>[];
      for (final s in sessions) {
        final msgs = await db.getAiMessagesForSession(s.id);
        sessionsData.add({
          'session': s.toMap(),
          'messages': msgs.map((m) => m.toMap()).toList(),
        });
      }
      _addJsonFile(archive, 'ai_sessions.json', sessionsData);
    }

    if (includeGlobalExtras) {
      final metrics = await db.getEconomicMetrics();
      final customMetrics = <Map<String, dynamic>>[];
      for (final m in metrics) {
        final benches = await db.getBenchmarksForMetric(m.id);
        customMetrics.add({
          'metric': m.toMap(),
          'benchmarks': benches.map((b) => b.toMap()).toList(),
        });
      }
      _addJsonFile(archive, 'global_extras.json', {
        'economic_models': customMetrics,
        'ai_role_presets':
            settings.aiRolePresets.map((r) => r.toJson()).toList(),
      });
    }

    final zipBytes = ZipEncoder().encode(archive)!;
    final dir = await _exportDir();
    final safeName = user.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final outPath = p.join(dir.path, '${safeName}_$stamp.userpkg.zip');
    await File(outPath).writeAsBytes(zipBytes, flush: true);
    return outPath;
  }

  static Future<UserPackageInspection> inspectUserPackage(
    String zipPath,
  ) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifest = _readJsonMap(archive, 'manifest.json');
    if (manifest == null || manifest['package_type'] != 'user_package') {
      throw const FormatException('不是有效的单用户数据包 (.userpkg.zip)');
    }
    final userName = (manifest['user'] as Map)['name'] as String;
    final existingUsers = await AppDatabase.instance.getUsers();
    UserAccount? sameName;
    for (final u in existingUsers) {
      if (u.name == userName) {
        sameName = u;
        break;
      }
    }
    final expenses = _readJsonList(archive, 'expenses.json') ?? const [];
    return UserPackageInspection(
      filePath: zipPath,
      manifest: manifest,
      existingSameNameUser: sameName,
      expenseCount: expenses.length,
      hasAiSessions: archive.findFile('ai_sessions.json') != null,
      hasGlobalExtras: archive.findFile('global_extras.json') != null,
    );
  }

  static Future<String> importUserPackage({
    required UserPackageInspection inspection,
    required UserImportConflictMode conflictMode,
    required bool importGlobalExtras,
    required AppSettings currentSettings,
  }) async {
    final db = AppDatabase.instance;
    final bytes = await File(inspection.filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifest = _readJsonMap(archive, 'manifest.json')!;
    final pkgUser = (manifest['user'] as Map).cast<String, dynamic>();
    final pkgUserName = pkgUser['name'] as String;

    // 1. Align categories by name, auto-create missing ones
    final pkgCats = (_readJsonList(archive, 'categories.json') ?? const [])
        .map((e) => ExpenseCategory.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
    final localCats = await db.getCategories();
    final localByName = {for (final c in localCats) c.name: c};
    final catIdMap = <String, String>{};
    var nextSort = localCats.length;
    final uncat = await db.getUncategorizedCategory();

    for (final pc in pkgCats) {
      if (pc.isUncategorized || pc.name == '未分类') {
        catIdMap[pc.id] = uncat.id;
      } else if (localByName.containsKey(pc.name)) {
        catIdMap[pc.id] = localByName[pc.name]!.id;
      } else {
        final newCat = ExpenseCategory(
          id: 'cat_${_uuid.v4()}',
          name: pc.name,
          isUncategorized: false,
          defaultColorHex: pc.defaultColorHex,
          sortOrder: nextSort++,
        );
        await db.upsertCategory(newCat);
        localByName[newCat.name] = newCat;
        catIdMap[pc.id] = newCat.id;
      }
    }

    // 2. Determine target user
    late UserAccount targetUser;
    final existing = inspection.existingSameNameUser;
    if (existing == null) {
      targetUser = UserAccount(
        id: 'user_${_uuid.v4()}',
        name: pkgUserName,
        authLevel: 0,
        activeThemeId: 'builtin_theme_light',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await db.upsertUser(targetUser);
    } else if (conflictMode == UserImportConflictMode.importAsNewUser) {
      var candidateName = '${pkgUserName}_导入';
      final allNames = (await db.getUsers()).map((u) => u.name).toSet();
      var idx = 2;
      while (allNames.contains(candidateName)) {
        candidateName = '${pkgUserName}_导入$idx';
        idx++;
      }
      targetUser = UserAccount(
        id: 'user_${_uuid.v4()}',
        name: candidateName,
        authLevel: 0,
        activeThemeId: existing.activeThemeId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await db.upsertUser(targetUser);
    } else {
      targetUser = existing;
      if (conflictMode == UserImportConflictMode.overwriteExisting) {
        final sqlDb = await db.database;
        await sqlDb.transaction((txn) async {
          await txn.delete(
            'expenses',
            where: 'user_id = ?',
            whereArgs: [targetUser.id],
          );
          await txn.delete(
            'user_day_overrides',
            where: 'user_id = ?',
            whereArgs: [targetUser.id],
          );
        });
      }
    }

    // 3. Import expenses (deduplicated by UUID on merge) & day overrides
    final pkgExpenses = (_readJsonList(archive, 'expenses.json') ?? const [])
        .map((e) => Expense.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
    final pkgOverrides =
        (_readJsonList(archive, 'user_day_overrides.json') ?? const [])
            .map(
              (e) =>
                  UserDayOverride.fromMap((e as Map).cast<String, dynamic>()),
            )
            .toList();

    final sqlDb = await db.database;
    var importedCount = 0;
    await sqlDb.transaction((txn) async {
      final existingIds = <String>{};
      if (conflictMode == UserImportConflictMode.mergeByUuid &&
          existing != null) {
        final rows = await txn.query(
          'expenses',
          columns: ['id'],
          where: 'user_id = ?',
          whereArgs: [targetUser.id],
        );
        for (final r in rows) {
          existingIds.add(r['id'] as String);
        }
      }

      final batch = txn.batch();
      for (final e in pkgExpenses) {
        final newExpenseId =
            conflictMode == UserImportConflictMode.importAsNewUser
                ? _uuid.v4()
                : e.id;
        if (existingIds.contains(newExpenseId)) continue;
        final mappedCatId = catIdMap[e.categoryId] ?? uncat.id;
        batch.insert(
          'expenses',
          e
              .copyWith(
                id: newExpenseId,
                userId: targetUser.id,
                categoryId: mappedCatId,
              )
              .toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        importedCount++;
      }

      for (final ov in pkgOverrides) {
        batch.insert(
          'user_day_overrides',
          {
            'user_id': targetUser.id,
            'date_str': ov.dateStr,
            'is_rest_day': ov.isRestDay ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });

    // 4. Optional AI sessions
    final aiSessionsRaw = _readJsonList(archive, 'ai_sessions.json');
    if (aiSessionsRaw != null) {
      for (final item in aiSessionsRaw) {
        if (item is! Map) continue;
        final sMap = (item['session'] as Map).cast<String, dynamic>();
        final session = AiChatSession.fromMap(sMap);
        final newSessionId = _uuid.v4();
        await db.upsertAiSession(
          AiChatSession(
            id: newSessionId,
            userId: targetUser.id,
            title: session.title,
            rolePresetId: session.rolePresetId,
            contextSummaryJson: session.contextSummaryJson,
            createdAt: session.createdAt,
          ),
        );
        final msgs = (item['messages'] as List?) ?? const [];
        for (final m in msgs) {
          if (m is! Map) continue;
          final msg = AiChatMessage.fromMap(m.cast<String, dynamic>());
          await db.upsertAiMessage(
            msg.copyWith(id: _uuid.v4(), sessionId: newSessionId),
          );
        }
      }
    }

    // 5. Optional global extras (economic models & AI role presets)
    if (importGlobalExtras) {
      final extras = _readJsonMap(archive, 'global_extras.json');
      if (extras != null) {
        final localMetrics = await db.getEconomicMetrics();
        final localMetricNames = localMetrics.map((m) => m.name).toSet();
        final models = (extras['economic_models'] as List?) ?? const [];
        for (final item in models) {
          if (item is! Map) continue;
          final m = EconomicMetric.fromMap(
            (item['metric'] as Map).cast<String, dynamic>(),
          );
          if (localMetricNames.contains(m.name)) continue;
          final newMetricId = 'metric_${_uuid.v4()}';
          final benches = ((item['benchmarks'] as List?) ?? const [])
              .map(
                (b) => EconomicBenchmark.fromMap(
                  (b as Map).cast<String, dynamic>(),
                ).copyWith(id: 'bench_${_uuid.v4()}', metricId: newMetricId),
              )
              .toList();
          await db.saveMetricWithBenchmarks(
            m.copyWith(id: newMetricId, isBuiltin: false),
            benches,
          );
          localMetricNames.add(m.name);
        }

        final presetsRaw = (extras['ai_role_presets'] as List?) ?? const [];
        if (presetsRaw.isNotEmpty) {
          final existingNames =
              currentSettings.aiRolePresets.map((p) => p.name).toSet();
          final mergedPresets = List<AiRolePreset>.from(
            currentSettings.aiRolePresets,
          );
          for (final item in presetsRaw) {
            if (item is! Map) continue;
            final rp = AiRolePreset.fromJson(item.cast<String, dynamic>());
            if (!existingNames.contains(rp.name)) {
              mergedPresets.add(
                rp.copyWith(id: 'role_${_uuid.v4()}', isBuiltin: false),
              );
              existingNames.add(rp.name);
            }
          }
          await SettingsService().save(
            currentSettings.copyWith(aiRolePresets: mergedPresets),
          );
        }
      }
    }

    return '已成功导入至用户「${targetUser.name}」，新增 $importedCount 条账单记录。';
  }

  // =========================================================================
  // 2. THEME PACKAGE (.themepkg.zip)
  // =========================================================================

  static Future<String> exportThemePackage(AppThemeRecord theme) async {
    final categories = await AppDatabase.instance.getCategories();
    final catById = {for (final c in categories) c.id: c};

    final archive = Archive();
    final exportedCategoryStyles = <String, dynamic>{};
    final packedPathCache = <String, String>{};
    var assetIdx = 0;

    Future<String?> packThemeAsset(String? localPath, String prefix) async {
      if (localPath == null || localPath.isEmpty) return null;
      if (packedPathCache.containsKey(localPath)) {
        return packedPathCache[localPath];
      }
      final file = File(localPath);
      if (!await file.exists()) return null;
      final ext = p.extension(localPath).isEmpty ? '.jpg' : p.extension(localPath);
      final relPath = 'assets/${prefix}_${assetIdx++}$ext';
      final imgBytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(relPath, imgBytes.length, imgBytes));
      packedPathCache[localPath] = relPath;
      return relPath;
    }

    // Export global background image if present
    final globalAssetRelPath = await packThemeAsset(
      theme.config.globalStyle.backgroundImagePath,
      'global_bg',
    );

    for (final entry in theme.config.categoryStyles.entries) {
      final cat = catById[entry.key];
      final catName = cat?.name ?? entry.key;
      final defaultColor = cat?.defaultColorHex ?? entry.value.themeColor;

      final catAssetRelPath = await packThemeAsset(
        entry.value.backgroundImagePath,
        'cat',
      );

      exportedCategoryStyles[catName] = {
        ...entry.value
            .copyWith(
              backgroundImagePath: catAssetRelPath,
              clearBackgroundImage: catAssetRelPath == null,
            )
            .toJson(),
        'default_color_hex': defaultColor,
      };
    }

    // Export candidate card style pool (including unbound styles & their assets!)
    final exportedPool = <Map<String, dynamic>>[];
    for (final preset in theme.config.cardStylePool) {
      final relPath = await packThemeAsset(
        preset.style.backgroundImagePath,
        'pool',
      );
      exportedPool.add(
        preset
            .copyWith(
              style: preset.style.copyWith(
                backgroundImagePath: relPath,
                clearBackgroundImage: relPath == null,
              ),
            )
            .toJson(),
      );
    }

    final exportedThemeJson = {
      'package_type': 'theme_package',
      'version': 1,
      'name': theme.name,
      'globalStyle': theme.config.globalStyle
          .copyWith(
            backgroundImagePath: globalAssetRelPath,
            clearBackgroundImage: globalAssetRelPath == null,
          )
          .toJson(),
      'dayTypeStyle': theme.config.dayTypeStyle.toJson(),
      'categoryStyles': exportedCategoryStyles,
      if (exportedPool.isNotEmpty) 'cardStylePool': exportedPool,
    };

    _addJsonFile(archive, 'theme.json', exportedThemeJson);

    final zipBytes = ZipEncoder().encode(archive)!;
    final dir = await _exportDir();
    final safeName = theme.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final outPath = p.join(dir.path, '${safeName}_$stamp.themepkg.zip');
    await File(outPath).writeAsBytes(zipBytes, flush: true);
    return outPath;
  }

  static Future<ThemePackageInspection> inspectThemePackage(
    String zipPath,
  ) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final themeJson = _readJsonMap(archive, 'theme.json');
    if (themeJson == null || themeJson['package_type'] != 'theme_package') {
      throw const FormatException('不是有效的主题包 (.themepkg.zip)');
    }
    final localCats = await AppDatabase.instance.getCategories();
    final localNames = localCats.map((c) => c.name).toSet();
    final rawCatStyles =
        (themeJson['categoryStyles'] as Map?)?.cast<String, dynamic>() ?? {};
    final missingNames = <String>[];
    final defaultColors = <String, String>{};
    for (final entry in rawCatStyles.entries) {
      if (!localNames.contains(entry.key)) {
        missingNames.add(entry.key);
        final map = (entry.value as Map).cast<String, dynamic>();
        defaultColors[entry.key] = (map['default_color_hex'] as String?) ??
            (map['themeColor'] as String?) ??
            ColorUtils.defaultCategoryPalette.first;
      }
    }
    return ThemePackageInspection(
      filePath: zipPath,
      themeName: (themeJson['name'] as String?) ?? '导入主题',
      missingCategoryNames: missingNames,
      missingCategoryDefaultColors: defaultColors,
    );
  }

  static Future<AppThemeRecord> importThemePackage({
    required ThemePackageInspection inspection,
    required bool createMissingCategories,
  }) async {
    final db = AppDatabase.instance;
    final bytes = await File(inspection.filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final themeJson = _readJsonMap(archive, 'theme.json')!;

    final newThemeId = 'theme_${_uuid.v4()}';
    final assetDir = await ImageService.themeAssetDir(newThemeId);

    Future<String?> extractAsset(String? relPath) async {
      if (relPath == null || relPath.isEmpty) return null;
      final file = archive.findFile(relPath);
      if (file == null) return null;
      final outPath = p.join(assetDir.path, p.basename(relPath));
      await File(outPath).writeAsBytes(file.content as List<int>, flush: true);
      return outPath;
    }

    // Align / optionally create categories
    final localCats = await db.getCategories();
    final localByName = {for (final c in localCats) c.name: c};
    var nextSort = localCats.length;
    if (createMissingCategories) {
      for (final missingName in inspection.missingCategoryNames) {
        if (localByName.containsKey(missingName)) continue;
        final newCat = ExpenseCategory(
          id: 'cat_${_uuid.v4()}',
          name: missingName,
          isUncategorized: false,
          defaultColorHex:
              inspection.missingCategoryDefaultColors[missingName] ??
                  ColorUtils.defaultCategoryPalette[
                      nextSort % ColorUtils.defaultCategoryPalette.length],
          sortOrder: nextSort++,
        );
        await db.upsertCategory(newCat);
        localByName[newCat.name] = newCat;
      }
    }

    final globalRaw =
        (themeJson['globalStyle'] as Map).cast<String, dynamic>();
    final localGlobalBg =
        await extractAsset(globalRaw['backgroundImagePath'] as String?);
    final globalStyle = GlobalStyleConfig.fromJson(globalRaw).copyWith(
      backgroundImagePath: localGlobalBg,
      clearBackgroundImage: localGlobalBg == null,
    );

    final dayTypeStyle = DayTypeStyleConfig.fromJson(
      (themeJson['dayTypeStyle'] as Map).cast<String, dynamic>(),
    );

    final rawCatStyles =
        (themeJson['categoryStyles'] as Map?)?.cast<String, dynamic>() ?? {};
    final mappedCatStyles = <String, CategoryStyleConfig>{};
    final candidatePool = <CardStylePreset>[];
    final seenPoolKeys = <String>{};

    void addToCandidatePool({
      required String name,
      String? defaultCategory,
      required CategoryStyleConfig style,
      String? existingId,
    }) {
      final dedupeKey =
          '$name|${style.backgroundImagePath ?? ''}|${style.themeColor.toUpperCase()}';
      if (seenPoolKeys.contains(dedupeKey)) return;
      seenPoolKeys.add(dedupeKey);
      candidatePool.add(
        CardStylePreset(
          id: (existingId != null && existingId.isNotEmpty)
              ? existingId
              : 'preset_${_uuid.v4().substring(0, 8)}',
          name: name,
          defaultCategory: defaultCategory,
          style: style,
        ),
      );
    }

    // 1. Extract ALL categoryStyles (even unmatched ones go into candidatePool so zero assets are wasted!)
    for (final entry in rawCatStyles.entries) {
      if (entry.value is! Map) continue;
      final styleMap = (entry.value as Map).cast<String, dynamic>();
      final localCatBg =
          await extractAsset(styleMap['backgroundImagePath'] as String?);
      final parsedStyle = CategoryStyleConfig.fromJson(styleMap).copyWith(
        backgroundImagePath: localCatBg,
        clearBackgroundImage: localCatBg == null,
      );

      addToCandidatePool(
        name: entry.key,
        defaultCategory: entry.key,
        style: parsedStyle,
      );

      final cat = localByName[entry.key];
      if (cat != null) {
        mappedCatStyles[cat.id] = parsedStyle;
      }
    }

    // 2. Also extract optional cardStylePool entries
    final rawPool = (themeJson['cardStylePool'] as List?) ?? const [];
    for (final item in rawPool) {
      if (item is! Map) continue;
      final itemMap = item.cast<String, dynamic>();
      final localBg =
          await extractAsset(itemMap['backgroundImagePath'] as String?);
      final preset = CardStylePreset.fromJson(itemMap);
      final resolvedStyle = preset.style.copyWith(
        backgroundImagePath: localBg,
        clearBackgroundImage: localBg == null,
      );

      addToCandidatePool(
        name: preset.name,
        defaultCategory: preset.defaultCategory,
        style: resolvedStyle,
        existingId: preset.id,
      );

      // If this pool item specifies a defaultCategory that exists locally and isn't bound yet, auto-bind!
      if (preset.defaultCategory != null &&
          localByName.containsKey(preset.defaultCategory)) {
        final targetCat = localByName[preset.defaultCategory]!;
        mappedCatStyles.putIfAbsent(targetCat.id, () => resolvedStyle);
      }
    }

    final themeRecord = AppThemeRecord(
      id: newThemeId,
      name: inspection.themeName,
      isBuiltin: false,
      config: ThemeConfig(
        globalStyle: globalStyle,
        dayTypeStyle: dayTypeStyle,
        categoryStyles: mappedCatStyles,
        cardStylePool: candidatePool,
      ),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await db.upsertTheme(themeRecord);
    return themeRecord;
  }

  // =========================================================================
  // 3. FULL DEVICE BACKUP (.fullbackup.zip)
  // =========================================================================

  static Future<String> exportFullBackup(AppSettings settings) async {
    final db = AppDatabase.instance;
    final dump = await db.exportAllTables();
    final archive = Archive();

    // Rewrite absolute theme image paths inside exported themes to portable relative paths
    final themesList = <Map<String, dynamic>>[];
    var assetCounter = 0;

    Future<String?> packImage(String? absPath) async {
      if (absPath == null || absPath.isEmpty) return null;
      final f = File(absPath);
      if (!await f.exists()) return null;
      final ext = p.extension(absPath).isEmpty ? '.jpg' : p.extension(absPath);
      final relPath = 'theme_assets/img_${assetCounter++}$ext';
      final bytes = await f.readAsBytes();
      archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
      return relPath;
    }

    for (final row in (dump['themes'] ?? const [])) {
      final theme = AppThemeRecord.fromMap(row);
      final globalRel = await packImage(theme.config.globalStyle.backgroundImagePath);
      final newCatStyles = <String, CategoryStyleConfig>{};
      for (final e in theme.config.categoryStyles.entries) {
        final catRel = await packImage(e.value.backgroundImagePath);
        newCatStyles[e.key] = e.value.copyWith(
          backgroundImagePath: catRel,
          clearBackgroundImage: catRel == null,
        );
      }
      final newPool = <CardStylePreset>[];
      for (final preset in theme.config.cardStylePool) {
        final poolRel = await packImage(preset.style.backgroundImagePath);
        newPool.add(
          preset.copyWith(
            style: preset.style.copyWith(
              backgroundImagePath: poolRel,
              clearBackgroundImage: poolRel == null,
            ),
          ),
        );
      }
      final portableTheme = theme.copyWith(
        config: theme.config.copyWith(
          globalStyle: theme.config.globalStyle.copyWith(
            backgroundImagePath: globalRel,
            clearBackgroundImage: globalRel == null,
          ),
          categoryStyles: newCatStyles,
          cardStylePool: newPool,
        ),
      );
      themesList.add(portableTheme.toMap());
    }

    dump['themes'] = themesList;

    _addJsonFile(archive, 'manifest.json', {
      'package_type': 'full_backup',
      'version': 1,
      'exported_at': DateTime.now().millisecondsSinceEpoch,
    });
    _addJsonFile(archive, 'database.json', dump);
    _addJsonFile(archive, 'settings.json', settings.toBackupJson());

    final zipBytes = ZipEncoder().encode(archive)!;
    final dir = await _exportDir();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final outPath = p.join(dir.path, 'jimi_fullbackup_$stamp.fullbackup.zip');
    await File(outPath).writeAsBytes(zipBytes, flush: true);
    return outPath;
  }

  static Future<AppSettings> importFullBackup(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifest = _readJsonMap(archive, 'manifest.json');
    if (manifest == null || manifest['package_type'] != 'full_backup') {
      throw const FormatException('不是有效的整机全量备份包 (.fullbackup.zip)');
    }
    final dbMapRaw = _readJsonMap(archive, 'database.json');
    final settingsRaw = _readJsonMap(archive, 'settings.json');
    if (dbMapRaw == null || settingsRaw == null) {
      throw const FormatException('备份包内容不完整');
    }

    final dump = <String, List<Map<String, dynamic>>>{};
    for (final entry in dbMapRaw.entries) {
      dump[entry.key] = (entry.value as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    }

    // Restore theme asset images to local documents directory
    final restoredThemes = <Map<String, dynamic>>[];
    for (final row in (dump['themes'] ?? const [])) {
      final theme = AppThemeRecord.fromMap(row);
      final assetDir = await ImageService.themeAssetDir(theme.id);

      Future<String?> unpackImage(String? relPath) async {
        if (relPath == null || relPath.isEmpty) return null;
        final file = archive.findFile(relPath);
        if (file == null) return null;
        final outPath = p.join(assetDir.path, p.basename(relPath));
        await File(outPath).writeAsBytes(file.content as List<int>, flush: true);
        return outPath;
      }

      final localGlobal =
          await unpackImage(theme.config.globalStyle.backgroundImagePath);
      final newCatStyles = <String, CategoryStyleConfig>{};
      for (final e in theme.config.categoryStyles.entries) {
        final localCat = await unpackImage(e.value.backgroundImagePath);
        newCatStyles[e.key] = e.value.copyWith(
          backgroundImagePath: localCat,
          clearBackgroundImage: localCat == null,
        );
      }
      final newPool = <CardStylePreset>[];
      for (final preset in theme.config.cardStylePool) {
        final localPool = await unpackImage(preset.style.backgroundImagePath);
        newPool.add(
          preset.copyWith(
            style: preset.style.copyWith(
              backgroundImagePath: localPool,
              clearBackgroundImage: localPool == null,
            ),
          ),
        );
      }

      final restored = theme.copyWith(
        config: theme.config.copyWith(
          globalStyle: theme.config.globalStyle.copyWith(
            backgroundImagePath: localGlobal,
            clearBackgroundImage: localGlobal == null,
          ),
          categoryStyles: newCatStyles,
          cardStylePool: newPool,
        ),
      );
      restoredThemes.add(restored.toMap());
    }
    dump['themes'] = restoredThemes;

    await AppDatabase.instance.restoreAllTables(dump);

    final presets = ((settingsRaw['ai_role_presets'] as List?) ?? const [])
        .map((e) => AiRolePreset.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final rawProfiles = (settingsRaw['llm_profiles'] as List?) ?? const [];
    final restoredProfiles = rawProfiles.isNotEmpty
        ? rawProfiles
            .map((e) => LlmProfile.fromJson((e as Map).cast<String, dynamic>()))
            .toList()
        : [
            LlmProfile(
              id: 'default_llm_profile',
              name: '默认配置',
              apiFormat: LlmApiFormat.openaiCompatible,
              baseUrl: (settingsRaw['llm_base_url'] as String?) ??
                  'https://api.deepseek.com/v1',
              apiKey: (settingsRaw['llm_api_key'] as String?) ?? '',
              modelName:
                  (settingsRaw['llm_model_name'] as String?) ?? 'deepseek-chat',
            ),
          ];
    final restoredActiveProfileId =
        (settingsRaw['active_llm_profile_id'] as String?) ??
            restoredProfiles.first.id;

    final restoredSettings = AppSettings(
      masterPinHash: settingsRaw['master_pin_hash'] as String?,
      masterPinSalt: settingsRaw['master_pin_salt'] as String?,
      currencySymbol: (settingsRaw['currency_symbol'] as String?) ?? '¥',
      llmProfiles: restoredProfiles,
      activeLlmProfileId: restoredActiveProfileId,
      aiRolePresets: presets,
      currentActiveUserId: settingsRaw['current_active_user_id'] as String?,
    );
    await SettingsService().save(restoredSettings);
    return restoredSettings;
  }
}
