import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../models/theme_config.dart';
import '../../providers/app_providers.dart';
import '../../services/backup_service.dart';
import '../../widgets/pin_dialog.dart';
import 'theme_editor_screen.dart';

class ThemeWorkshopScreen extends ConsumerWidget {
  static const _uuid = Uuid();
  const ThemeWorkshopScreen({super.key});

  Future<void> _createNewTheme(BuildContext context, WidgetRef ref) async {
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
      reason: '创建自定义主题需要验证权限',
    );
    if (!ok || !context.mounted) return;

    final base = ref.read(appControllerProvider).activeTheme;
    final newTheme = AppThemeRecord(
      id: 'theme_${_uuid.v4()}',
      name: '我的自定义主题',
      isBuiltin: false,
      config: base.config,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThemeEditorScreen(themeRecord: newTheme, isNew: true),
      ),
    );
  }

  Future<void> _duplicateTheme(
    BuildContext context,
    WidgetRef ref,
    AppThemeRecord src,
  ) async {
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
    );
    if (!ok || !context.mounted) return;

    final copy = AppThemeRecord(
      id: 'theme_${_uuid.v4()}',
      name: '${src.name} 副本',
      isBuiltin: false,
      config: src.config,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.read(appControllerProvider.notifier).saveTheme(copy);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已复制主题「${copy.name}」')),
      );
    }
  }

  Future<void> _exportTheme(
    BuildContext context,
    AppThemeRecord theme,
  ) async {
    try {
      final zipPath = await BackupService.exportThemePackage(theme);
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: '保存主题包 (.themepkg.zip)',
          fileName: '${theme.name}.themepkg.zip',
        );
        if (savePath != null) {
          await File(zipPath).copy(savePath);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('主题包已导出至：$savePath')),
            );
          }
        }
      } else {
        await Share.shareXFiles(
          [XFile(zipPath)],
          subject: '基米记账主题包 - ${theme.name}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出主题包失败：$e')),
        );
      }
    }
  }

  Future<void> _importTheme(BuildContext context, WidgetRef ref) async {
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
      reason: '导入主题包需要验证权限',
    );
    if (!ok || !context.mounted) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null || picked.files.single.path == null) return;

    try {
      final inspection =
          await BackupService.inspectThemePackage(picked.files.single.path!);
      bool createMissing = false;
      if (inspection.missingCategoryNames.isNotEmpty && context.mounted) {
        final choice = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('发现本地缺失类别'),
            content: Text(
              '主题包「${inspection.themeName}」包含以下本地尚未创建的类别：\n'
              '${inspection.missingCategoryNames.join("、")}\n\n'
              '无论是否创建类别，所有卡片样式都会完整收录进本主题的「候选库」，随时可在主题编辑器一键绑定。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('取消'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('同时创建缺失类别'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('仅收录到候选库（推荐）'),
              ),
            ],
          ),
        );
        if (choice == null) return;
        createMissing = choice;
      }

      final imported = await BackupService.importThemePackage(
        inspection: inspection,
        createMissingCategories: createMissing,
      );
      await ref.read(appControllerProvider.notifier).reloadAll();
      if (context.mounted) {
        final poolCount = imported.config.cardStylePool.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已导入主题「${imported.name}」（共收录 $poolCount 套卡片样式至候选库）',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入主题包失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final activeId = state.activeTheme.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('主题工坊'),
        actions: [
          IconButton(
            tooltip: '导入 .themepkg.zip 主题包',
            onPressed: () => _importTheme(context, ref),
            icon: const Icon(Icons.file_upload_outlined),
          ),
          IconButton(
            tooltip: '新建自定义主题',
            onPressed: () => _createNewTheme(context, ref),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: state.themes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final theme = state.themes[i];
          final g = theme.config.globalStyle;
          final isActive = theme.id == activeId;

          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: isActive
                  ? BorderSide(color: g.primary, width: 2.2)
                  : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: g.primary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: g.isDarkText
                                ? Colors.black12
                                : Colors.white38,
                          ),
                        ),
                        child: Icon(
                          g.isDarkText
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    theme.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (theme.isBuiltin) ...[
                                  const SizedBox(width: 6),
                                  const Chip(
                                    label: Text('内置', style: TextStyle(fontSize: 10)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '${g.isDarkText ? "浅色底" : "深色底"} · ${g.backgroundImagePath != null ? "含背景图" : "纯色背景"}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (isActive)
                        const Chip(
                          avatar: Icon(Icons.check_circle, size: 16),
                          label: Text('已启用'),
                        )
                      else
                        FilledButton.tonal(
                          onPressed: () async {
                            await ref
                                .read(appControllerProvider.notifier)
                                .bindThemeToCurrentUser(theme.id);
                          },
                          child: const Text('启用'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await AuthGuard.requireAction(
                            context,
                            ref,
                            ProtectedAction.modifyOrDelete,
                          );
                          if (!ok || !context.mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ThemeEditorScreen(
                                themeRecord: theme,
                                isNew: false,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.brush_rounded, size: 16),
                        label: const Text('深度定制'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _duplicateTheme(context, ref, theme),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('复制'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _exportTheme(context, theme),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('导出主题包'),
                      ),
                      if (!theme.isBuiltin)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () async {
                            final ok = await AuthGuard.requireAction(
                              context,
                              ref,
                              ProtectedAction.modifyOrDelete,
                            );
                            if (!ok) return;
                            await ref
                                .read(appControllerProvider.notifier)
                                .deleteTheme(theme.id);
                          },
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('删除'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
