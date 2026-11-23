import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/db/app_database.dart';
import '../data/seed_data.dart';
import '../models/ai_models.dart';
import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/economic_models.dart';
import '../models/expense.dart';
import '../models/theme_config.dart';
import '../models/user_account.dart';
import '../services/settings_service.dart';
import '../utils/pin_crypto.dart';

class PendingAiAnalysisRequest {
  final String title;
  final String contextPrompt;
  final DateTime startDate;
  final DateTime endDate;
  final EconomicComparisonSnapshot? economicSnapshot;

  const PendingAiAnalysisRequest({
    required this.title,
    required this.contextPrompt,
    required this.startDate,
    required this.endDate,
    this.economicSnapshot,
  });
}

class AppState {
  final bool isInitialized;
  final AppSettings settings;
  final List<UserAccount> users;
  final String? currentUserId;
  final bool isSessionUnlocked;
  final List<ExpenseCategory> categories;
  final List<AppThemeRecord> themes;
  final List<Expense> expenses;
  final Map<String, bool> dayOverrides;
  final List<EconomicMetric> economicMetrics;
  final Map<String, List<EconomicBenchmark>> benchmarksByMetric;
  final List<AiChatSession> aiSessions;
  final int insightsSubTab;
  final PendingAiAnalysisRequest? pendingAiRequest;

  const AppState({
    this.isInitialized = false,
    this.settings = const AppSettings(),
    this.users = const [],
    this.currentUserId,
    this.isSessionUnlocked = false,
    this.categories = const [],
    this.themes = const [],
    this.expenses = const [],
    this.dayOverrides = const {},
    this.economicMetrics = const [],
    this.benchmarksByMetric = const {},
    this.aiSessions = const [],
    this.insightsSubTab = 0,
    this.pendingAiRequest,
  });

  bool get needsOnboarding => !settings.hasMasterPin || users.isEmpty;

  UserAccount? get currentUser {
    if (users.isEmpty) return null;
    for (final u in users) {
      if (u.id == currentUserId) return u;
    }
    return users.first;
  }

  bool get isLockedForViewing {
    final user = currentUser;
    if (user == null) return false;
    return user.authLevel >= 3 && !isSessionUnlocked;
  }

  AppThemeRecord get activeTheme {
    final user = currentUser;
    if (themes.isEmpty) {
      return SeedData.initialThemes(0).first;
    }
    if (user != null) {
      for (final t in themes) {
        if (t.id == user.activeThemeId) return t;
      }
    }
    return themes.first;
  }

  ExpenseCategory categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    for (final c in categories) {
      if (c.isUncategorized) return c;
    }
    return SeedData.initialCategories().last;
  }

  AppState copyWith({
    bool? isInitialized,
    AppSettings? settings,
    List<UserAccount>? users,
    String? currentUserId,
    bool? isSessionUnlocked,
    List<ExpenseCategory>? categories,
    List<AppThemeRecord>? themes,
    List<Expense>? expenses,
    Map<String, bool>? dayOverrides,
    List<EconomicMetric>? economicMetrics,
    Map<String, List<EconomicBenchmark>>? benchmarksByMetric,
    List<AiChatSession>? aiSessions,
    int? insightsSubTab,
    PendingAiAnalysisRequest? pendingAiRequest,
    bool clearPendingAiRequest = false,
  }) {
    return AppState(
      isInitialized: isInitialized ?? this.isInitialized,
      settings: settings ?? this.settings,
      users: users ?? this.users,
      currentUserId: currentUserId ?? this.currentUserId,
      isSessionUnlocked: isSessionUnlocked ?? this.isSessionUnlocked,
      categories: categories ?? this.categories,
      themes: themes ?? this.themes,
      expenses: expenses ?? this.expenses,
      dayOverrides: dayOverrides ?? this.dayOverrides,
      economicMetrics: economicMetrics ?? this.economicMetrics,
      benchmarksByMetric: benchmarksByMetric ?? this.benchmarksByMetric,
      aiSessions: aiSessions ?? this.aiSessions,
      insightsSubTab: insightsSubTab ?? this.insightsSubTab,
      pendingAiRequest: clearPendingAiRequest
          ? null
          : (pendingAiRequest ?? this.pendingAiRequest),
    );
  }
}

class AppController extends StateNotifier<AppState> {
  static const _uuid = Uuid();
  final SettingsService _settingsService = SettingsService();
  final AppDatabase _db = AppDatabase.instance;

  AppController() : super(const AppState()) {
    initialize();
  }

  Future<void> initialize() async {
    final settings = await _settingsService.load();
    await _loadAllFromStorage(settings, resetSessionUnlock: true);
  }

  Future<void> reloadAll({bool resetSessionUnlock = false}) async {
    final settings = await _settingsService.load();
    await _loadAllFromStorage(settings, resetSessionUnlock: resetSessionUnlock);
  }

  Future<void> _loadAllFromStorage(
    AppSettings settings, {
    required bool resetSessionUnlock,
  }) async {
    final users = await _db.getUsers();
    final categories = await _db.getCategories();
    final themes = await _db.getThemes();
    final metrics = await _db.getEconomicMetrics();
    final allBenchmarks = await _db.getAllBenchmarks();
    final benchMap = <String, List<EconomicBenchmark>>{};
    for (final b in allBenchmarks) {
      benchMap.putIfAbsent(b.metricId, () => []).add(b);
    }

    String? activeUserId = settings.currentActiveUserId;
    if (users.isNotEmpty && !users.any((u) => u.id == activeUserId)) {
      activeUserId = users.first.id;
    }

    List<Expense> expenses = const [];
    Map<String, bool> overrides = const {};
    List<AiChatSession> aiSessions = const [];
    if (activeUserId != null) {
      expenses = await _db.getExpensesForUser(activeUserId);
      overrides = await _db.getDayOverridesForUser(activeUserId);
      aiSessions = await _db.getAiSessionsForUser(activeUserId);
    }

    state = state.copyWith(
      isInitialized: true,
      settings: settings.copyWith(currentActiveUserId: activeUserId),
      users: users,
      currentUserId: activeUserId,
      isSessionUnlocked: resetSessionUnlock ? false : state.isSessionUnlocked,
      categories: categories,
      themes: themes,
      expenses: expenses,
      dayOverrides: overrides,
      economicMetrics: metrics,
      benchmarksByMetric: benchMap,
      aiSessions: aiSessions,
    );
  }

  // ==================== AUTH & ONBOARDING ====================

  Future<void> completeOnboarding({
    required String masterPin,
    required String firstUserName,
  }) async {
    final salt = PinCrypto.generateSalt();
    final hash = PinCrypto.hashPin(masterPin, salt);
    final now = DateTime.now().millisecondsSinceEpoch;
    final firstUser = UserAccount(
      id: 'user_${_uuid.v4()}',
      name: firstUserName.trim(),
      authLevel: 0,
      activeThemeId: SeedData.themeLightId,
      createdAt: now,
    );
    await _db.upsertUser(firstUser);
    final updatedSettings = state.settings.copyWith(
      masterPinHash: hash,
      masterPinSalt: salt,
      currentActiveUserId: firstUser.id,
    );
    await _settingsService.save(updatedSettings);
    await _loadAllFromStorage(updatedSettings, resetSessionUnlock: true);
  }

  bool verifyMasterPin(String inputPin) {
    return PinCrypto.verifyPin(
      inputPin,
      state.settings.masterPinHash,
      state.settings.masterPinSalt,
    );
  }

  /// Universal verification: accepts either target user's PIN OR Master PIN!
  bool verifyUserOrMasterPin(String inputPin, UserAccount targetUser) {
    if (verifyMasterPin(inputPin)) return true;
    return PinCrypto.verifyPin(inputPin, targetUser.pinHash, targetUser.pinSalt);
  }

  void setSessionUnlocked(bool unlocked) {
    state = state.copyWith(isSessionUnlocked: unlocked);
  }

  void lockSession() {
    state = state.copyWith(isSessionUnlocked: false);
  }

  Future<void> updateMasterPin(String newMasterPin) async {
    final salt = PinCrypto.generateSalt();
    final hash = PinCrypto.hashPin(newMasterPin, salt);
    final updated = state.settings.copyWith(
      masterPinHash: hash,
      masterPinSalt: salt,
    );
    await _settingsService.save(updated);
    state = state.copyWith(settings: updated);
  }

  // ==================== USER MANAGEMENT ====================

  Future<void> switchUser(String userId, {bool alreadyVerified = false}) async {
    final updatedSettings =
        state.settings.copyWith(currentActiveUserId: userId);
    await _settingsService.save(updatedSettings);
    final expenses = await _db.getExpensesForUser(userId);
    final overrides = await _db.getDayOverridesForUser(userId);
    final aiSessions = await _db.getAiSessionsForUser(userId);
    state = state.copyWith(
      settings: updatedSettings,
      currentUserId: userId,
      isSessionUnlocked: alreadyVerified,
      expenses: expenses,
      dayOverrides: overrides,
      aiSessions: aiSessions,
    );
  }

  Future<UserAccount> createUser({
    required String name,
    required int authLevel,
    String? pin,
    String? themeId,
  }) async {
    String? pinHash;
    String? pinSalt;
    if (authLevel > 0 && pin != null && pin.isNotEmpty) {
      pinSalt = PinCrypto.generateSalt();
      pinHash = PinCrypto.hashPin(pin, pinSalt);
    }
    final user = UserAccount(
      id: 'user_${_uuid.v4()}',
      name: name.trim(),
      authLevel: authLevel,
      pinHash: pinHash,
      pinSalt: pinSalt,
      activeThemeId: themeId ?? SeedData.themeLightId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.upsertUser(user);
    final users = await _db.getUsers();
    state = state.copyWith(users: users);
    return user;
  }

  Future<void> updateUser(UserAccount user) async {
    await _db.upsertUser(user);
    final users = await _db.getUsers();
    state = state.copyWith(users: users);
  }

  Future<void> deleteUser(String userId) async {
    if (state.users.length <= 1) {
      throw StateError('至少需要保留一个用户');
    }
    await _db.deleteUserCascade(userId);
    final users = await _db.getUsers();
    if (state.currentUserId == userId) {
      await switchUser(users.first.id);
    } else {
      state = state.copyWith(users: users);
    }
  }

  Future<void> bindThemeToCurrentUser(String themeId) async {
    final user = state.currentUser;
    if (user == null) return;
    await updateUser(user.copyWith(activeThemeId: themeId));
  }

  // ==================== SETTINGS ====================

  Future<void> updateCurrencySymbol(String symbol) async {
    final updated = state.settings.copyWith(currencySymbol: symbol);
    await _settingsService.save(updated);
    state = state.copyWith(settings: updated);
  }

  Future<void> saveLlmProfiles(
    List<LlmProfile> profiles, {
    String? activeProfileId,
  }) async {
    final safeList =
        profiles.isEmpty ? const [LlmProfile.defaultProfile] : profiles;
    final resolvedActive = activeProfileId != null &&
            safeList.any((p) => p.id == activeProfileId)
        ? activeProfileId
        : (safeList.any((p) => p.id == state.settings.activeLlmProfileId)
            ? state.settings.activeLlmProfileId
            : safeList.first.id);
    final updated = state.settings.copyWith(
      llmProfiles: safeList,
      activeLlmProfileId: resolvedActive,
    );
    await _settingsService.save(updated);
    state = state.copyWith(settings: updated);
  }

  Future<void> selectActiveLlmProfile(String profileId) async {
    if (!state.settings.llmProfiles.any((p) => p.id == profileId)) return;
    final updated = state.settings.copyWith(activeLlmProfileId: profileId);
    await _settingsService.save(updated);
    state = state.copyWith(settings: updated);
  }

  Future<void> updateAiRolePresets(List<AiRolePreset> presets) async {
    final updated = state.settings.copyWith(aiRolePresets: presets);
    await _settingsService.save(updated);
    state = state.copyWith(settings: updated);
  }

  // ==================== CATEGORIES ====================

  Future<void> saveCategory(ExpenseCategory category) async {
    await _db.upsertCategory(category);
    final categories = await _db.getCategories();
    state = state.copyWith(categories: categories);
  }

  Future<void> deleteCategory(String categoryId) async {
    await _db.deleteCategoryAndReassign(categoryId);
    await reloadAll();
  }

  // ==================== EXPENSES ====================

  Future<bool> resolveIsRestDay(String dateStr) async {
    final userId = state.currentUserId;
    if (userId == null) return false;
    return _db.resolveIsRestDay(userId, dateStr);
  }

  Future<bool> saveExpense(Expense expense) async {
    final syncedOthers = await _db.saveExpenseWithDaySync(expense);
    if (state.currentUserId != null) {
      final expenses = await _db.getExpensesForUser(state.currentUserId!);
      final overrides = await _db.getDayOverridesForUser(state.currentUserId!);
      state = state.copyWith(expenses: expenses, dayOverrides: overrides);
    }
    return syncedOthers;
  }

  Future<void> deleteExpense(String expenseId) async {
    await _db.deleteExpense(expenseId);
    if (state.currentUserId != null) {
      final expenses = await _db.getExpensesForUser(state.currentUserId!);
      state = state.copyWith(expenses: expenses);
    }
  }

  Future<void> batchDeleteExpenses(List<String> ids) async {
    await _db.batchDeleteExpenses(ids);
    if (state.currentUserId != null) {
      final expenses = await _db.getExpensesForUser(state.currentUserId!);
      state = state.copyWith(expenses: expenses);
    }
  }

  Future<void> batchUpdateExpenseCategory(
    List<String> ids,
    String targetCategoryId,
  ) async {
    await _db.batchUpdateCategory(ids, targetCategoryId);
    if (state.currentUserId != null) {
      final expenses = await _db.getExpensesForUser(state.currentUserId!);
      state = state.copyWith(expenses: expenses);
    }
  }

  // ==================== THEMES ====================

  Future<void> saveTheme(AppThemeRecord theme) async {
    await _db.upsertTheme(theme);
    final themes = await _db.getThemes();
    state = state.copyWith(themes: themes);
  }

  Future<void> deleteTheme(String themeId) async {
    await _db.deleteTheme(themeId);
    await reloadAll();
  }

  // ==================== ECONOMICS ====================

  Future<void> saveEconomicModel(
    EconomicMetric metric,
    List<EconomicBenchmark> benchmarks, {
    bool replaceBenchmarks = true,
  }) async {
    await _db.saveMetricWithBenchmarks(
      metric,
      benchmarks,
      replaceBenchmarks: replaceBenchmarks,
    );
    await _refreshEconomics();
  }

  Future<void> upsertBenchmark(EconomicBenchmark benchmark) async {
    await _db.upsertBenchmark(benchmark);
    await _refreshEconomics();
  }

  Future<void> deleteBenchmark(String benchmarkId) async {
    await _db.deleteBenchmark(benchmarkId);
    await _refreshEconomics();
  }

  Future<void> deleteEconomicMetric(String metricId) async {
    await _db.deleteEconomicMetric(metricId);
    await _refreshEconomics();
  }

  Future<void> _refreshEconomics() async {
    final metrics = await _db.getEconomicMetrics();
    final allBenchmarks = await _db.getAllBenchmarks();
    final benchMap = <String, List<EconomicBenchmark>>{};
    for (final b in allBenchmarks) {
      benchMap.putIfAbsent(b.metricId, () => []).add(b);
    }
    state = state.copyWith(
      economicMetrics: metrics,
      benchmarksByMetric: benchMap,
    );
  }

  // ==================== INSIGHTS & AI SESSIONS ====================

  void setInsightsSubTab(int index) {
    state = state.copyWith(insightsSubTab: index);
  }

  void triggerOneClickAiAnalysis(PendingAiAnalysisRequest req) {
    state = state.copyWith(
      insightsSubTab: 1,
      pendingAiRequest: req,
    );
  }

  void clearPendingAiRequest() {
    state = state.copyWith(clearPendingAiRequest: true);
  }

  Future<void> refreshAiSessions() async {
    final uid = state.currentUserId;
    if (uid == null) return;
    final sessions = await _db.getAiSessionsForUser(uid);
    state = state.copyWith(aiSessions: sessions);
  }

  Future<void> deleteAiSession(String sessionId) async {
    await _db.deleteAiSession(sessionId);
    await refreshAiSessions();
  }
}

final appControllerProvider =
    StateNotifierProvider<AppController, AppState>((ref) {
  return AppController();
});
