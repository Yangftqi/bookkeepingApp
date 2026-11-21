import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../widgets/themed_background.dart';
import '../widgets/user_switcher_sheet.dart';
import 'bills/bills_tab.dart';
import 'insights/insights_tab.dart';
import 'settings/settings_tab.dart';
import 'stats/stats_tab.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tabIndex = 0;

  IconData _levelIcon(int level) {
    switch (level) {
      case 0:
        return Icons.lock_open_rounded;
      case 1:
        return Icons.shield_outlined;
      case 2:
        return Icons.verified_user_outlined;
      case 3:
        return Icons.lock_rounded;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final user = state.currentUser;
    final themeCfg = state.activeTheme.config;
    final g = themeCfg.globalStyle;

    return ThemedBackground(
      themeConfig: themeCfg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: g.surface.withOpacity(0.88),
          foregroundColor: g.textColor,
          elevation: 0,
          titleSpacing: 12,
          title: Row(
            children: [
              // User switcher pill
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => showUserSwitcherSheet(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: g.primary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: g.primary.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _levelIcon(user?.authLevel ?? 0),
                        size: 16,
                        color: g.primary,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Text(
                          user?.name ?? '基米记账',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: g.textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: g.secondaryTextColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  const ['账单', '统计', '洞察', '设置'][_tabIndex],
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: g.textColor,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if ((user?.authLevel ?? 0) > 0)
              Tooltip(
                message: state.isSessionUnlocked
                    ? '已解锁 · 点击立即上锁'
                    : '当前受密码保护（已锁定）',
                child: IconButton(
                  onPressed: state.isSessionUnlocked
                      ? () {
                          ref.read(appControllerProvider.notifier).lockSession();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('当前会话已锁定')),
                          );
                        }
                      : null,
                  icon: Icon(
                    state.isSessionUnlocked
                        ? Icons.lock_open_rounded
                        : Icons.lock_outline_rounded,
                    color: state.isSessionUnlocked
                        ? Colors.green
                        : g.secondaryTextColor,
                  ),
                ),
              ),
          ],
        ),
        body: IndexedStack(
          index: _tabIndex,
          children: const [
            BillsTab(),
            StatsTab(),
            InsightsTab(),
            SettingsTab(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          backgroundColor: g.surface.withOpacity(0.95),
          indicatorColor: g.primary.withOpacity(0.18),
          onDestinationSelected: (i) => setState(() => _tabIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: '账单',
            ),
            NavigationDestination(
              icon: Icon(Icons.pie_chart_outline_rounded),
              selectedIcon: Icon(Icons.pie_chart_rounded),
              label: '统计',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded),
              label: '洞察',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}
