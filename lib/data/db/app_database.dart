import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/ai_models.dart';
import '../../models/category.dart';
import '../../models/economic_models.dart';
import '../../models/expense.dart';
import '../../models/theme_config.dart';
import '../../models/user_account.dart';
import '../../utils/date_utils_ext.dart';
import '../seed_data.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  static const _dbName = 'jimi_bookkeeping.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  /// For unit testing with an in-memory or custom path database.
  Future<void> initForTest(Database db) async {
    _db = db;
  }

  static void ensureFfiInitialized() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> _initDatabase() async {
    ensureFfiInitialized();
    final Directory baseDir;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      baseDir = await getApplicationSupportDirectory();
    } else {
      baseDir = Directory(await getDatabasesPath());
    }
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    final dbPath = p.join(baseDir.path, _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: createSchemaAndSeed,
    );
  }

  static Future<void> createSchemaAndSeed(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        auth_level INTEGER NOT NULL DEFAULT 0,
        pin_hash TEXT,
        pin_salt TEXT,
        active_theme_id TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        is_uncategorized INTEGER NOT NULL DEFAULT 0,
        default_color_hex TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        date_str TEXT NOT NULL,
        is_rest_day INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_expenses_user_date ON expenses(user_id, date_str)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_user_ts ON expenses(user_id, timestamp DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_category ON expenses(category_id)',
    );

    await db.execute('''
      CREATE TABLE user_day_overrides (
        user_id TEXT NOT NULL,
        date_str TEXT NOT NULL,
        is_rest_day INTEGER NOT NULL,
        PRIMARY KEY (user_id, date_str)
      )
    ''');

    await db.execute('''
      CREATE TABLE themes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_builtin INTEGER NOT NULL DEFAULT 0,
        config_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE economic_metrics (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        denominator_type TEXT NOT NULL DEFAULT 'total_expense',
        suggested_category_keywords TEXT NOT NULL DEFAULT '[]',
        is_builtin INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE economic_benchmarks (
        id TEXT PRIMARY KEY,
        metric_id TEXT NOT NULL,
        name TEXT NOT NULL,
        is_tier_standard INTEGER NOT NULL DEFAULT 0,
        value REAL NOT NULL,
        max_value REAL,
        note TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (metric_id) REFERENCES economic_metrics(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_benchmarks_metric ON economic_benchmarks(metric_id)',
    );

    await db.execute('''
      CREATE TABLE ai_chat_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        role_preset_id TEXT NOT NULL,
        context_summary_json TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_chat_messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES ai_chat_sessions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_ai_messages_session ON ai_chat_messages(session_id, created_at ASC)',
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final c in SeedData.initialCategories()) {
      batch.insert('categories', c.toMap());
    }
    for (final t in SeedData.initialThemes(now)) {
      batch.insert('themes', t.toMap());
    }
    batch.insert('economic_metrics', SeedData.engelMetric(now).toMap());
    for (final b in SeedData.engelBenchmarks()) {
      batch.insert('economic_benchmarks', b.toMap());
    }
    await batch.commit(noResult: true);
  }

  // ==================== USERS ====================

  Future<List<UserAccount>> getUsers() async {
    final db = await database;
    final rows = await db.query('users', orderBy: 'created_at ASC');
    return rows.map(UserAccount.fromMap).toList();
  }

  Future<void> upsertUser(UserAccount user) async {
    final db = await database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteUserCascade(String userId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('expenses', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete(
        'user_day_overrides',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.delete(
        'ai_chat_sessions',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.delete('users', where: 'id = ?', whereArgs: [userId]);
    });
  }

  // ==================== CATEGORIES ====================

  Future<List<ExpenseCategory>> getCategories() async {
    final db = await database;
    final rows = await db.query(
      'categories',
      orderBy: 'is_uncategorized ASC, sort_order ASC, name ASC',
    );
    return rows.map(ExpenseCategory.fromMap).toList();
  }

  Future<ExpenseCategory> getUncategorizedCategory() async {
    final db = await database;
    final rows = await db.query(
      'categories',
      where: 'is_uncategorized = 1',
      limit: 1,
    );
    if (rows.isNotEmpty) return ExpenseCategory.fromMap(rows.first);
    const fallback = ExpenseCategory(
      id: SeedData.catUncategorizedId,
      name: '未分类',
      isUncategorized: true,
      defaultColorHex: '#FF64748B',
      sortOrder: 9999,
    );
    await db.insert(
      'categories',
      fallback.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return fallback;
  }

  Future<void> upsertCategory(ExpenseCategory category) async {
    final db = await database;
    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Atomically deletes a non-uncategorized category, reassigns ALL users' expenses
  /// to the permanent '未分类' category, and removes its key from all themes.
  Future<void> deleteCategoryAndReassign(String categoryId) async {
    final db = await database;
    final uncat = await getUncategorizedCategory();
    if (categoryId == uncat.id) {
      throw StateError('系统常驻“未分类”不可删除');
    }
    await db.transaction((txn) async {
      final catRows = await txn.query(
        'categories',
        where: 'id = ?',
        whereArgs: [categoryId],
        limit: 1,
      );
      if (catRows.isEmpty) return;
      final oldName = catRows.first['name'] as String;

      await txn.update(
        'expenses',
        {'category_id': uncat.id},
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [categoryId]);

      final themeRows = await txn.query('themes');
      for (final row in themeRows) {
        final theme = AppThemeRecord.fromMap(row);
        if (theme.config.categoryStyles.containsKey(categoryId) ||
            theme.config.categoryStyles.containsKey(oldName)) {
          final updatedMap =
              Map<String, CategoryStyleConfig>.from(theme.config.categoryStyles)
                ..remove(categoryId)
                ..remove(oldName);
          final updatedTheme = theme.copyWith(
            config: theme.config.copyWith(categoryStyles: updatedMap),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          await txn.update(
            'themes',
            updatedTheme.toMap(),
            where: 'id = ?',
            whereArgs: [theme.id],
          );
        }
      }
    });
  }

  // ==================== EXPENSES & SAME-DAY OVERRIDES ====================

  Future<List<Expense>> getExpensesForUser(String userId) async {
    final db = await database;
    final rows = await db.query(
      'expenses',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC, created_at DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<Map<String, bool>> getDayOverridesForUser(String userId) async {
    final db = await database;
    final rows = await db.query(
      'user_day_overrides',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final result = <String, bool>{};
    for (final row in rows) {
      final raw = row['is_rest_day'];
      result[row['date_str'] as String] = raw == true || raw == 1;
    }
    return result;
  }

  /// Resolves effective workday/rest-day state for `(userId, dateStr)`.
  Future<bool> resolveIsRestDay(String userId, String dateStr) async {
    final db = await database;
    final rows = await db.query(
      'user_day_overrides',
      where: 'user_id = ? AND date_str = ?',
      whereArgs: [userId, dateStr],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final raw = rows.first['is_rest_day'];
      return raw == true || raw == 1;
    }
    return DateUtilsExt.isDefaultWeekendStr(dateStr);
  }

  /// Atomically inserts/updates an expense AND synchronizes same-day workday/rest-day
  /// binding across `user_day_overrides` and ALL expenses of `(userId, dateStr)`.
  /// Returns `true` if other expenses on that same day were synced to the new state.
  Future<bool> saveExpenseWithDaySync(Expense expense) async {
    final db = await database;
    var syncedOthers = false;
    await db.transaction((txn) async {
      await txn.insert(
        'expenses',
        expense.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'user_day_overrides',
        {
          'user_id': expense.userId,
          'date_str': expense.dateStr,
          'is_rest_day': expense.isRestDay ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final updatedCount = await txn.update(
        'expenses',
        {
          'is_rest_day': expense.isRestDay ? 1 : 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'user_id = ? AND date_str = ? AND is_rest_day != ?',
        whereArgs: [expense.userId, expense.dateStr, expense.isRestDay ? 1 : 0],
      );
      syncedOthers = updatedCount > 0;
    });
    return syncedOthers;
  }

  Future<void> deleteExpense(String expenseId) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [expenseId]);
  }

  Future<void> batchDeleteExpenses(List<String> expenseIds) async {
    if (expenseIds.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in expenseIds) {
        batch.delete('expenses', where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> batchUpdateCategory(
    List<String> expenseIds,
    String targetCategoryId,
  ) async {
    if (expenseIds.isEmpty) return;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in expenseIds) {
        batch.update(
          'expenses',
          {'category_id': targetCategoryId, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  // ==================== THEMES ====================

  Future<List<AppThemeRecord>> getThemes() async {
    final db = await database;
    final rows = await db.query(
      'themes',
      orderBy: 'is_builtin DESC, updated_at DESC',
    );
    return rows.map(AppThemeRecord.fromMap).toList();
  }

  Future<void> upsertTheme(AppThemeRecord theme) async {
    final db = await database;
    await db.insert(
      'themes',
      theme.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTheme(String themeId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'users',
        {'active_theme_id': SeedData.themeLightId},
        where: 'active_theme_id = ?',
        whereArgs: [themeId],
      );
      await txn.delete('themes', where: 'id = ?', whereArgs: [themeId]);
    });
  }

  // ==================== ECONOMICS ====================

  Future<List<EconomicMetric>> getEconomicMetrics() async {
    final db = await database;
    final rows = await db.query(
      'economic_metrics',
      orderBy: 'is_builtin DESC, updated_at DESC',
    );
    return rows.map(EconomicMetric.fromMap).toList();
  }

  Future<List<EconomicBenchmark>> getBenchmarksForMetric(
    String metricId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'economic_benchmarks',
      where: 'metric_id = ?',
      whereArgs: [metricId],
      orderBy: 'is_tier_standard DESC, value ASC',
    );
    return rows.map(EconomicBenchmark.fromMap).toList();
  }

  Future<List<EconomicBenchmark>> getAllBenchmarks() async {
    final db = await database;
    final rows = await db.query('economic_benchmarks');
    return rows.map(EconomicBenchmark.fromMap).toList();
  }

  Future<void> saveMetricWithBenchmarks(
    EconomicMetric metric,
    List<EconomicBenchmark> benchmarks, {
    bool replaceBenchmarks = true,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'economic_metrics',
        metric.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (replaceBenchmarks) {
        await txn.delete(
          'economic_benchmarks',
          where: 'metric_id = ?',
          whereArgs: [metric.id],
        );
      }
      final batch = txn.batch();
      for (final b in benchmarks) {
        batch.insert(
          'economic_benchmarks',
          b.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertBenchmark(EconomicBenchmark benchmark) async {
    final db = await database;
    await db.insert(
      'economic_benchmarks',
      benchmark.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBenchmark(String benchmarkId) async {
    final db = await database;
    await db.delete(
      'economic_benchmarks',
      where: 'id = ?',
      whereArgs: [benchmarkId],
    );
  }

  Future<void> deleteEconomicMetric(String metricId) async {
    final db = await database;
    await db.delete(
      'economic_metrics',
      where: 'id = ?',
      whereArgs: [metricId],
    );
  }

  // ==================== AI CHAT ====================

  Future<List<AiChatSession>> getAiSessionsForUser(String userId) async {
    final db = await database;
    final rows = await db.query(
      'ai_chat_sessions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(AiChatSession.fromMap).toList();
  }

  Future<List<AiChatMessage>> getAiMessagesForSession(String sessionId) async {
    final db = await database;
    final rows = await db.query(
      'ai_chat_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return rows.map(AiChatMessage.fromMap).toList();
  }

  Future<void> upsertAiSession(AiChatSession session) async {
    final db = await database;
    await db.insert(
      'ai_chat_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertAiMessage(AiChatMessage message) async {
    final db = await database;
    await db.insert(
      'ai_chat_messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAiSession(String sessionId) async {
    final db = await database;
    await db.delete(
      'ai_chat_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // ==================== BULK BACKUP / RESTORE HELPERS ====================

  Future<Map<String, List<Map<String, dynamic>>>> exportAllTables() async {
    final db = await database;
    return {
      'users': await db.query('users'),
      'categories': await db.query('categories'),
      'expenses': await db.query('expenses'),
      'user_day_overrides': await db.query('user_day_overrides'),
      'themes': await db.query('themes'),
      'economic_metrics': await db.query('economic_metrics'),
      'economic_benchmarks': await db.query('economic_benchmarks'),
      'ai_chat_sessions': await db.query('ai_chat_sessions'),
      'ai_chat_messages': await db.query('ai_chat_messages'),
    };
  }

  Future<void> restoreAllTables(
    Map<String, List<Map<String, dynamic>>> dump,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('ai_chat_messages');
      await txn.delete('ai_chat_sessions');
      await txn.delete('economic_benchmarks');
      await txn.delete('economic_metrics');
      await txn.delete('user_day_overrides');
      await txn.delete('expenses');
      await txn.delete('users');
      await txn.delete('themes');
      await txn.delete('categories');

      const order = [
        'categories',
        'themes',
        'users',
        'expenses',
        'user_day_overrides',
        'economic_metrics',
        'economic_benchmarks',
        'ai_chat_sessions',
        'ai_chat_messages',
      ];

      for (final table in order) {
        final rows = dump[table] ?? const [];
        final batch = txn.batch();
        for (final row in rows) {
          batch.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    });
  }
}
