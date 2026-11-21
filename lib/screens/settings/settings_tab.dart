import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/update_checker_service.dart';
import '../../widgets/pin_dialog.dart';
import '../insights/llm_config_dialog.dart';
import '../insights/role_presets_dialog.dart';
import 'backup_center_screen.dart';
import 'category_management_screen.dart';
import 'theme_workshop_screen.dart';
import 'user_management_screen.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  Future<void> _pickCurrency(BuildContext context, WidgetRef ref) async {
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
      reason: '修改全局货币符号需要验证权限',
    );
    if (!ok || !context.mounted) return;

    final current = ref.read(appControllerProvider).settings.currencySymbol;
    const presets = ['¥', '\$', '€', '£', '无符号'];
    final customCtrl = TextEditingController(
      text: presets.contains(current) ? '' : current,
    );

    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('全局货币符号'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '全软件所有用户共享同一货币前缀符号',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((sym) {
                return ChoiceChip(
                  label: Text(sym),
                  selected: current == sym,
                  onSelected: (_) => Navigator.of(ctx).pop(sym),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: customCtrl,
              decoration: const InputDecoration(
                labelText: '自定义前缀符号（如 HK\$、RMB）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final custom = customCtrl.text.trim();
              if (custom.isEmpty) return;
              Navigator.of(ctx).pop(custom);
            },
            child: const Text('应用'),
          ),
        ],
      ),
    );
    if (chosen != null) {
      await ref
          .read(appControllerProvider.notifier)
          .updateCurrencySymbol(chosen);
    }
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('正在从 GitHub 检查最新版本...')),
          ],
        ),
      ),
    );

    UpdateCheckResult? result;
    Object? err;
    try {
      result = await UpdateCheckerService.checkForUpdates();
    } catch (e) {
      err = e;
    }

    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (err != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('检查更新失败'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$err', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              SelectableText(
                '仓库地址：${UpdateCheckerService.repoUrl}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  const ClipboardData(text: UpdateCheckerService.repoUrl),
                );
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('已复制仓库链接')),
                  );
                }
              },
              child: const Text('复制仓库链接'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
      return;
    }

    final res = result!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(res.hasUpdate ? '发现新版本 v${res.latestVersion}' : '当前已是最新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前版本：v${res.currentVersion}\n最新版本：v${res.latestVersion}',
              style: const TextStyle(fontSize: 13),
            ),
            if (res.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Text(
                    res.releaseNotes,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            SelectableText(
              res.downloadUrl,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(res.hasUpdate ? '暂不更新' : '关闭'),
          ),
          OutlinedButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: res.downloadUrl));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('已复制 GitHub 仓库链接')),
                );
              }
            },
            child: const Text('复制链接'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final opened =
                  await UpdateCheckerService.tryOpenInBrowser(res.downloadUrl);
              if (!opened && ctx.mounted) {
                await Clipboard.setData(ClipboardData(text: res.downloadUrl));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('已复制链接，请在浏览器中粘贴打开')),
                  );
                }
              }
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(res.hasUpdate ? '前往仓库下载' : '打开仓库'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final g = state.activeTheme.config.globalStyle;

    Widget sectionCard(List<Widget> children) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: g.surface.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
        ),
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
            trailing: Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
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
            trailing: Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
            onTap: () => _pickCurrency(context, ref),
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
            trailing: Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
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
            trailing: Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
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
            trailing: Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
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
              '当前模型：${state.settings.llmModelName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: g.secondaryTextColor),
            ),
            trailing: Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
            onTap: () => showLlmConfigDialog(context, ref),
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
            trailing: Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
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
            trailing: Icon(Icons.chevron_right_rounded, color: g.secondaryTextColor),
            onTap: () => _checkForUpdates(context),
          ),
        ]),
      ],
    );
  }
}
