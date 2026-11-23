import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/update_checker_service.dart';
import '../../widgets/glass_surface.dart';
import '../insights/role_presets_dialog.dart';
import 'backup_center_screen.dart';
import 'category_management_screen.dart';
import 'currency_settings_screen.dart';
import 'llm_profiles_screen.dart';
import 'theme_workshop_screen.dart';
import 'update_check_screen.dart';
import 'user_management_screen.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final themeCfg = state.activeTheme.config;
    final g = themeCfg.globalStyle;

    Widget sectionCard(List<Widget> children) {
      return GlassSurface(
        themeConfig: themeCfg,
        margin: const EdgeInsets.only(bottom: 12),
        borderRadius: 18,
        child: Column(children: children),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
      children: [
        sectionCard([
          ListTile(
            leading: CircleAvatar(
              backgroundColor: g.primary.withOpacity(0.14),
              child: Icon(Icons.group_rounded, color: g.primary),
            ),
            title: Text(
              '多用户与安全权限管理',
              style: TextStyle(fontWeight: FontWeight.w700, color: g.textColor),
            ),
            subtitle: Text(
              '当前共 ${state.users.length} 个用户',
              style: TextStyle(fontSize: 12, color: g.secondaryTextColor),
            ),
            trailing:
                Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UserManagementScreen()),
            ),
          ),
        ]),
        sectionCard([
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.withOpacity(0.14),
              child: const Icon(Icons.currency_yen_rounded, color: Colors.teal),
            ),
            title: Text(
              '全局货币符号',
              style: TextStyle(fontWeight: FontWeight.w700, color: g.textColor),
            ),
            subtitle: Text(
              '当前：${state.settings.currencySymbol}',
              style: TextStyle(fontSize: 12, color: g.secondaryTextColor),
            ),
            trailing:
                Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CurrencySettingsScreen(),
              ),
            ),
          ),
          const Divider(height: 1, indent: 68),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.14),
              child: const Icon(Icons.category_rounded, color: Colors.orange),
            ),
            title: Text(
              '全局支出类别管理',
              style: TextStyle(fontWeight: FontWeight.w700, color: g.textColor),
            ),
            subtitle: Text(
              '当前共 ${state.categories.length} 个类别',
              style: TextStyle(fontSize: 12, color: g.secondaryTextColor),
            ),
            trailing:
                Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CategoryManagementScreen(),
              ),
            ),
          ),
        ]),
        sectionCard([
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.withOpacity(0.14),
              child: const Icon(Icons.palette_rounded, color: Colors.purple),
            ),
            title: Text(
              '主题工坊',
              style: TextStyle(fontWeight: FontWeight.w700, color: g.textColor),
            ),
            subtitle: Text(
              '当前启用：${state.activeTheme.name}',
              style: TextStyle(fontSize: 12, color: g.secondaryTextColor),
            ),
            trailing:
                Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ThemeWorkshopScreen()),
            ),
          ),
        ]),
        sectionCard([
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.14),
              child: const Icon(Icons.archive_rounded, color: Colors.blue),
            ),
            title: Text(
              '数据导入导出与备份',
              style: TextStyle(fontWeight: FontWeight.w700, color: g.textColor),
            ),
            subtitle: Text(
              '用户数据包 · 主题包 · 整机备份',
              style: TextStyle(fontSize: 12, color: g.secondaryTextColor),
            ),
            trailing:
                Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BackupCenterScreen()),
            ),
          ),
        ]),
        sectionCard([
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.withOpacity(0.14),
              child: const Icon(Icons.key_rounded, color: Colors.indigo),
            ),
            title: Text(
              '全局大模型 API 配置',
              style: TextStyle(fontWeight: FontWeight.w700, color: g.textColor),
            ),
            subtitle: Text(
              '当前：${state.settings.activeLlmProfile.name} (${state.settings.llmModelName})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: g.secondaryTextColor),
            ),
            trailing:
                Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LlmProfilesScreen()),
            ),
          ),
          const Divider(height: 1, indent: 68),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.pink.withOpacity(0.14),
              child: const Icon(Icons.masks_rounded, color: Colors.pink),
            ),
            title: Text(
              'AI 分析角色预设',
              style: TextStyle(fontWeight: FontWeight.w700, color: g.textColor),
            ),
            subtitle: Text(
              '当前共 ${state.settings.aiRolePresets.length} 个角色',
              style: TextStyle(fontSize: 12, color: g.secondaryTextColor),
            ),
            trailing:
                Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
            onTap: () => showRolePresetsDialog(context, ref),
          ),
        ]),
        sectionCard([
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.14),
              child: const Icon(Icons.system_update_rounded, color: Colors.green),
            ),
            title: Text(
              '检查更新',
              style: TextStyle(fontWeight: FontWeight.w700, color: g.textColor),
            ),
            subtitle: Text(
              '当前版本 v${UpdateCheckerService.currentVersion}',
              style: TextStyle(fontSize: 12, color: g.secondaryTextColor),
            ),
            trailing:
                Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UpdateCheckScreen()),
            ),
          ),
        ]),
      ],
    );
  }
}
