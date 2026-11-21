import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../providers/app_providers.dart';
import '../../services/backup_service.dart';
import '../../widgets/pin_dialog.dart';

class BackupCenterScreen extends ConsumerStatefulWidget {
  const BackupCenterScreen({super.key});

  @override
  ConsumerState<BackupCenterScreen> createState() => _BackupCenterScreenState();
}

class _BackupCenterScreenState extends ConsumerState<BackupCenterScreen> {
  String? _selectedUserId;
  bool _includeAiSessions = true;
  bool _includeGlobalExtras = true;
  String? _selectedThemeId;
  bool _busy = false;

  Future<void> _deliverExportedFile(String zipPath, String title) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: title,
        fileName: p.basename(zipPath),
      );
      if (savePath != null) {
        await File(zipPath).copy(savePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已导出保存至：$savePath')),
          );
        }
      }
    } else {
      await Share.shareXFiles([XFile(zipPath)], subject: title);
    }
  }

  Future<void> _exportUserPackage() async {
    final state = ref.read(appControllerProvider);
    final user = state.users.firstWhere(
      (u) => u.id == _selectedUserId,
      orElse: () => state.users.first,
    );

    // Enforces target user PIN check (and cross-user anti-escalation)!
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
      targetUser: user,
      reason: '导出用户「${user.name}」的数据包需要验证该用户 PIN 码或超级管理员主 PIN 码',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final zipPath = await BackupService.exportUserPackage(
        user: user,
        includeAiSessions: _includeAiSessions,
        includeGlobalExtras: _includeGlobalExtras,
        settings: state.settings,
      );
      await _deliverExportedFile(zipPath, '导出单用户数据包 (.userpkg.zip)');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importUserPackage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null || picked.files.single.path == null) return;

    try {
      final inspection =
          await BackupService.inspectUserPackage(picked.files.single.path!);
      var mode = UserImportConflictMode.mergeByUuid;
      bool importExtras = inspection.hasGlobalExtras;

      if (inspection.existingSameNameUser != null && mounted) {
        final chosen = await showDialog<UserImportConflictMode>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('检测到同名本地用户'),
            content: Text(
              '本地已存在名为「${inspection.existingSameNameUser!.name}」的用户，数据包内含 ${inspection.expenseCount} 条账单。请选择导入方式：',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('取消'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx)
                    .pop(UserImportConflictMode.importAsNewUser),
                child: const Text('作为新用户导入'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx)
                    .pop(UserImportConflictMode.overwriteExisting),
                child: const Text('覆盖原账单'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(UserImportConflictMode.mergeByUuid),
                child: const Text('合并账单(按UUID去重)'),
              ),
            ],
          ),
        );
        if (chosen == null) return;
        mode = chosen;

        // If merging into or overwriting an existing protected user, verify THAT user's PIN!
        if (mode != UserImportConflictMode.importAsNewUser) {
          final target = inspection.existingSameNameUser!;
          if (!mounted) return;
          final ok = await AuthGuard.requireAction(
            context,
            ref,
            ProtectedAction.modifyOrDelete,
            targetUser: target,
            reason: '合并或覆盖受保护用户「${target.name}」的数据需要验证其 PIN 码或主 PIN 码',
          );
          if (!ok) return;
        }
      }

      setState(() => _busy = true);
      final msg = await BackupService.importUserPackage(
        inspection: inspection,
        conflictMode: mode,
        importGlobalExtras: importExtras,
        currentSettings: ref.read(appControllerProvider).settings,
      );
      await ref.read(appControllerProvider.notifier).reloadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入用户数据包失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportThemePackage() async {
    final state = ref.read(appControllerProvider);
    final theme = state.themes.firstWhere(
      (t) => t.id == _selectedThemeId,
      orElse: () => state.activeTheme,
    );
    setState(() => _busy = true);
    try {
      final zipPath = await BackupService.exportThemePackage(theme);
      await _deliverExportedFile(zipPath, '导出主题包 (.themepkg.zip)');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出主题包失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importThemePackage() async {
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
      reason: '导入主题包需要验证权限',
    );
    if (!ok || !mounted) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null || picked.files.single.path == null) return;

    try {
      final inspection =
          await BackupService.inspectThemePackage(picked.files.single.path!);
      bool createMissing = false;
      if (inspection.missingCategoryNames.isNotEmpty && mounted) {
        final choice = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('主题包包含本地缺失类别'),
            content: Text(
              '以下类别在本地不存在：${inspection.missingCategoryNames.join("、")}\n'
              '是否一键创建这些类别并完整绑定主题样式与卡片背景图？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('跳过缺失类别'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('一键创建并绑定'),
              ),
            ],
          ),
        );
        if (choice == null) return;
        createMissing = choice;
      }

      setState(() => _busy = true);
      final imported = await BackupService.importThemePackage(
        inspection: inspection,
        createMissingCategories: createMissing,
      );
      await ref.read(appControllerProvider.notifier).reloadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('主题「${imported.name}」导入成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入主题包失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportFullBackup() async {
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.masterOnly,
      reason: '导出整机全量备份包 (.fullbackup.zip) 必须验证超级管理员主 PIN 码',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final zipPath = await BackupService.exportFullBackup(
        ref.read(appControllerProvider).settings,
      );
      await _deliverExportedFile(zipPath, '导出整机全量备份包 (.fullbackup.zip)');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('整机全量导出失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFullBackup() async {
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.masterOnly,
      reason: '导入整机全量备份包将完全覆盖当前设备数据，必须验证超级管理员主 PIN 码',
    );
    if (!ok || !mounted) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null || picked.files.single.path == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('整机覆盖还原确认'),
        content: const Text(
          '即将使用所选 .fullbackup.zip 覆盖本机的所有用户、账单、类别、主题图片、经济学模型与 AI 对话记录。确定继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认覆盖还原'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await BackupService.importFullBackup(picked.files.single.path!);
      await ref
          .read(appControllerProvider.notifier)
          .reloadAll(resetSessionUnlock: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('整机全量备份已 100% 还原！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('整机还原失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    if (_selectedUserId == null && state.currentUser != null) {
      _selectedUserId = state.currentUser!.id;
    }
    if (_selectedThemeId == null && state.themes.isNotEmpty) {
      _selectedThemeId = state.activeTheme.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据导入导出与备份'),
        actions: [
          IconButton(
            tooltip: '备份格式说明',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('数据包与备份说明'),
                  content: const Text(
                    '• 单用户数据包 (.userpkg.zip)：打包指定用户的账单与关联类别；导入时自动对齐缺失类别，同名用户支持按 UUID 去重合并、覆盖或作为新用户导入。\n\n'
                    '• 主题包 (.themepkg.zip)：包含主题配置与全部背景图片；导入时若发现本地缺失类别，可一键创建并绑定。\n\n'
                    '• 整机全量备份 (.fullbackup.zip)：需验证超级管理员主密码，完整备份或还原所有用户、账单、主题、经济学模型、AI 角色与历史会话。',
                  ),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // 1. Single User Package
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '单用户数据包',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: state.users.any((u) => u.id == _selectedUserId)
                            ? _selectedUserId
                            : state.users.first.id,
                        decoration: const InputDecoration(
                          labelText: '目标用户',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: state.users
                            .map(
                              (u) => DropdownMenuItem(
                                value: u.id,
                                child: Text('${u.name} (${u.authLevelLabel})'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedUserId = v),
                      ),
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('附带 AI 对话记录'),
                        value: _includeAiSessions,
                        onChanged: (v) =>
                            setState(() => _includeAiSessions = v ?? true),
                      ),
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('附带自定义经济学模型与 AI 角色'),
                        value: _includeGlobalExtras,
                        onChanged: (v) =>
                            setState(() => _includeGlobalExtras = v ?? true),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _exportUserPackage,
                              icon: const Icon(Icons.file_download_outlined),
                              label: const Text('导出'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _importUserPackage,
                              icon: const Icon(Icons.file_upload_outlined),
                              label: const Text('导入'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Theme Package
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '主题包',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: state.themes.any((t) => t.id == _selectedThemeId)
                            ? _selectedThemeId
                            : state.activeTheme.id,
                        decoration: const InputDecoration(
                          labelText: '目标主题',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: state.themes
                            .map(
                              (t) => DropdownMenuItem(
                                value: t.id,
                                child: Text(t.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedThemeId = v),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _exportThemePackage,
                              icon: const Icon(Icons.file_download_outlined),
                              label: const Text('导出'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _importThemePackage,
                              icon: const Icon(Icons.file_upload_outlined),
                              label: const Text('导入'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. Full Device Backup
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.security_rounded, color: Color(0xFF4F46E5), size: 20),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '整机全量备份',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _exportFullBackup,
                              icon: const Icon(Icons.backup_rounded),
                              label: const Text('全量导出'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _importFullBackup,
                              icon: const Icon(Icons.restore_rounded),
                              label: const Text('全量还原'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_busy)
            const ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
