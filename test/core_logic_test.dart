import 'package:bookkeeping_app/data/db/app_database.dart';
import 'package:bookkeeping_app/data/seed_data.dart';
import 'package:bookkeeping_app/models/ai_models.dart';
import 'package:bookkeeping_app/models/expense.dart';
import 'package:bookkeeping_app/models/theme_config.dart';
import 'package:bookkeeping_app/models/user_account.dart';
import 'package:bookkeeping_app/services/llm_service.dart';
import 'package:bookkeeping_app/services/update_checker_service.dart';
import 'package:bookkeeping_app/utils/date_utils_ext.dart';
import 'package:bookkeeping_app/utils/math_evaluator.dart';
import 'package:bookkeeping_app/utils/pin_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('MathEvaluator', () {
    test('evaluates arithmetic expressions with operator precedence', () {
      expect(MathEvaluator.evaluate('128 + 36 ÷ 2'), 146.0);
      expect(MathEvaluator.evaluate('10.5 × 2 − 3.25'), 17.75);
      expect(MathEvaluator.evaluate('100 ÷ 3'), 33.33);
      expect(MathEvaluator.evaluate('50+'), 50.0);
      expect(MathEvaluator.evaluate('10 ÷ 0'), isNull);
    });
  });

  group('PinCrypto', () {
    test('hashes and verifies 4-6 digit PINs securely with salt', () {
      expect(PinCrypto.isValidPinFormat('1234'), isTrue);
      expect(PinCrypto.isValidPinFormat('123456'), isTrue);
      expect(PinCrypto.isValidPinFormat('123'), isFalse);
      expect(PinCrypto.isValidPinFormat('1234567'), isFalse);
      expect(PinCrypto.isValidPinFormat('abcd'), isFalse);

      final salt = PinCrypto.generateSalt();
      final hash = PinCrypto.hashPin('2468', salt);
      expect(PinCrypto.verifyPin('2468', hash, salt), isTrue);
      expect(PinCrypto.verifyPin('1357', hash, salt), isFalse);
    });
  });

  group('DateUtilsExt', () {
    test('enumerates calendar days inclusively and identifies weekends', () {
      final days = DateUtilsExt.enumerateDays(
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 7),
      );
      expect(days.length, 7);
      // 2026-11-21 is Saturday
      expect(DateUtilsExt.isDefaultWeekend(DateTime(2026, 11, 21)), isTrue);
      expect(DateUtilsExt.isDefaultWeekend(DateTime(2026, 11, 20)), isFalse);
    });
  });

  group('LlmService economic JSON parser', () {
    test('parses strict economic model schema cleanly', () {
      final parsed = LlmService.parseGeneratedEconomicJson({
        'name': '文化娱乐消费占比',
        'description': '文化与娱乐支出占个人总消费的比例',
        'denominator_type': 'total_expense',
        'suggested_category_keywords': ['玩', '电影'],
        'tier_standards': [
          {'name': '低投入 (<5%)', 'value': 0.0, 'max_value': 5.0, 'note': '保守'},
          {'name': '均衡 (5%~100%)', 'value': 5.0, 'max_value': 100.0, 'note': '丰富'},
        ],
        'benchmarks': [
          {'name': '美国', 'value': 9.2, 'note': 'OECD'},
          {'name': '日本', 'value': 8.5, 'note': '统计局'},
        ],
      });
      expect(parsed.metric.name, '文化娱乐消费占比');
      expect(parsed.benchmarks.where((b) => b.isTierStandard).length, 2);
      expect(parsed.benchmarks.where((b) => !b.isTierStandard).length, 2);
    });
  });

  group('AppDatabase schema, seed data, day sync, and category reassignment', () {
    late Database db;

    setUp(() async {
      sqfliteFfiInit();
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: AppDatabase.createSchemaAndSeed,
        ),
      );
      await AppDatabase.instance.initForTest(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('seeds 4 categories, 2 themes, Engel metric + 6 tiers + 37 countries', () async {
      final cats = await AppDatabase.instance.getCategories();
      final themes = await AppDatabase.instance.getThemes();
      final metrics = await AppDatabase.instance.getEconomicMetrics();
      final engelBenches =
          await AppDatabase.instance.getBenchmarksForMetric(SeedData.engelMetricId);

      expect(cats.length, 4);
      expect(cats.any((c) => c.isUncategorized && c.name == '未分类'), isTrue);
      expect(themes.length, 2);
      expect(metrics.length, 1);
      expect(engelBenches.where((b) => b.isTierStandard).length, 6);
      expect(engelBenches.where((b) => !b.isTierStandard).length, 37);
    });

    test('same-day workday/rest-day binding synchronizes all bills of that day', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await AppDatabase.instance.upsertUser(
        UserAccount(
          id: 'u1',
          name: '测试用户',
          authLevel: 0,
          activeThemeId: SeedData.themeLightId,
          createdAt: now,
        ),
      );

      final e1 = Expense(
        id: 'e1',
        userId: 'u1',
        amount: 25.0,
        categoryId: SeedData.catFoodId,
        timestamp: DateTime(2026, 11, 20, 12, 0).millisecondsSinceEpoch,
        dateStr: '2026-11-20',
        isRestDay: false,
        note: '午餐',
        createdAt: now,
        updatedAt: now,
      );
      await AppDatabase.instance.saveExpenseWithDaySync(e1);

      // Save second expense on the same date switched to rest day = true
      final e2 = Expense(
        id: 'e2',
        userId: 'u1',
        amount: 60.0,
        categoryId: SeedData.catPlayId,
        timestamp: DateTime(2026, 11, 20, 19, 0).millisecondsSinceEpoch,
        dateStr: '2026-11-20',
        isRestDay: true,
        note: '请假调休看电影',
        createdAt: now,
        updatedAt: now,
      );
      final syncedOthers = await AppDatabase.instance.saveExpenseWithDaySync(e2);
      expect(syncedOthers, isTrue);

      final list = await AppDatabase.instance.getExpensesForUser('u1');
      expect(list.length, 2);
      expect(list.every((e) => e.isRestDay == true), isTrue);
      expect(await AppDatabase.instance.resolveIsRestDay('u1', '2026-11-20'), isTrue);
    });

    test('deleting a category reassigns expenses across users to permanent 未分类', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await AppDatabase.instance.saveExpenseWithDaySync(
        Expense(
          id: 'e_food',
          userId: 'u1',
          amount: 42.0,
          categoryId: SeedData.catFoodId,
          timestamp: now,
          dateStr: '2026-11-21',
          isRestDay: true,
          note: '奶茶',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await AppDatabase.instance.deleteCategoryAndReassign(SeedData.catFoodId);
      final list = await AppDatabase.instance.getExpensesForUser('u1');
      expect(list.single.categoryId, SeedData.catUncategorizedId);
    });
  });

  group('AiRolePreset templates and UpdateCheckerService', () {
    test('provides 9 default AI role presets with concise taglines and fallback', () {
      final presets = SeedData.defaultAiRolePresets();
      expect(presets.length, 9);
      expect(presets.first.tagline, '严谨 客观 经济学家');
      expect(presets.every((p) => p.tagline.trim().isNotEmpty), isTrue);

      const customWithoutTagline = AiRolePreset(
        id: 'custom_1',
        name: '自定义角色',
        tagline: '',
        systemPrompt: '你是一个专注餐饮分析的助手',
        isBuiltin: false,
      );
      expect(customWithoutTagline.displayTagline, '你是一个专注餐饮分析的助手');
    });

    test('compares semantic versions accurately', () {
      expect(UpdateCheckerService.isNewerVersion('v1.0.1', '1.0.0'), isTrue);
      expect(UpdateCheckerService.isNewerVersion('1.1.0+2', '1.0.9+5'), isTrue);
      expect(UpdateCheckerService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(UpdateCheckerService.isNewerVersion('0.9.9', '1.0.0'), isFalse);
    });

    test('serializes ThemeConfig cardStylePool and stays v1 backward compatible', () {
      final v1Json = SeedData.initialThemes(0).first.config.toJson();
      expect(v1Json.containsKey('cardStylePool'), isFalse);
      final parsedV1 = ThemeConfig.fromJson(v1Json);
      expect(parsedV1.cardStylePool, isEmpty);

      final withPool = parsedV1.copyWith(
        cardStylePool: const [
          CardStylePreset(
            id: 'p1',
            name: '樱花甜品',
            defaultCategory: '吃的',
            style: CategoryStyleConfig(
              themeColor: '#FFF43F5E',
              backgroundImagePath: 'assets/cat_food.jpg',
              cardOverlayOpacity: 0.45,
              cardBlurSigma: 2.0,
            ),
          ),
        ],
      );
      final roundTrip = ThemeConfig.fromJsonString(withPool.toJsonString());
      expect(roundTrip.cardStylePool.length, 1);
      expect(roundTrip.cardStylePool.first.name, '樱花甜品');
      expect(roundTrip.cardStylePool.first.defaultCategory, '吃的');
      expect(roundTrip.cardStylePool.first.style.themeColor, '#FFF43F5E');
    });

    test('parses model lists for OpenAI, Gemini native, and Claude native APIs', () {
      final openAiModels = LlmService.parseModelListResponse(
        LlmApiFormat.openaiCompatible,
        {
          'data': [
            {'id': 'deepseek-reasoner'},
            {'id': 'deepseek-chat'},
          ],
        },
      );
      expect(openAiModels, ['deepseek-chat', 'deepseek-reasoner']);

      final geminiModels = LlmService.parseModelListResponse(
        LlmApiFormat.gemini,
        {
          'models': [
            {
              'name': 'models/gemini-2.5-flash',
              'supportedGenerationMethods': ['generateContent'],
            },
            {
              'name': 'models/text-embedding-004',
              'supportedGenerationMethods': ['embedContent'],
            },
          ],
        },
      );
      expect(geminiModels, ['gemini-2.5-flash']);

      final claudeModels = LlmService.parseModelListResponse(
        LlmApiFormat.claude,
        {
          'data': [
            {'id': 'claude-sonnet-4-20250514'},
          ],
        },
      );
      expect(claudeModels, ['claude-sonnet-4-20250514']);
    });

    test('GlobalStyleConfig accentTextFollowsPrimary defaults true and toggles cleanly', () {
      final legacy = GlobalStyleConfig.fromJson({
        'primaryColor': '#FF4F46E5',
        'surfaceColor': '#E6FFFFFF',
        'isDarkText': true,
      });
      expect(legacy.accentTextFollowsPrimary, isTrue);
      expect(legacy.accentTextColor, legacy.primary);
      expect(legacy.toJson().containsKey('accentTextFollowsPrimary'), isFalse);

      final decoupled = legacy.copyWith(accentTextFollowsPrimary: false);
      expect(decoupled.accentTextColor, decoupled.textColor);
      final roundTrip = GlobalStyleConfig.fromJson(decoupled.toJson());
      expect(roundTrip.accentTextFollowsPrimary, isFalse);
      expect(roundTrip.accentTextColor, roundTrip.textColor);
    });
  });
}
