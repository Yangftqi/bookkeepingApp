import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_account.dart';
import '../../providers/app_providers.dart';
import '../../utils/pin_crypto.dart';
import '../../widgets/pin_dialog.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  Future<void> _changeMasterPin(BuildContext context, WidgetRef ref) async {
    final verified = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.masterOnly,
      reason: '修改超级管理员主 PIN 码前，请先验证当前主 PIN 码',
    );
    if (!verified || !context.mounted) return;

    final newPin = await showPinSetupDialog(
      context: context,
      title: '设置新的超级管理员主 PIN 码',
      subtitle: '请输入新的 4~6 位数字主密码',
    );
    if (newPin == null) return;

    await ref.read(appControllerProvider.notifier).updateMasterPin(newPin);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('超级管理员主 PIN 码已更新')),
      );
    }
  }

  Future<void> _addUser(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    int level = 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('新增记账用户'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: level,
                decoration: const InputDecoration(
                  labelText: '安全级别',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('级别 0：无密码（打开即用）')),
                  DropdownMenuItem(value: 1, child: Text('级别 1：删改保护')),
                  DropdownMenuItem(value: 2, child: Text('级别 2：增删改保护')),
                  DropdownMenuItem(value: 3, child: Text('级别 3：增删改查全保护')),
                ],
                onChanged: (v) => setState(() => level = v ?? 0),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    String? pin;
    if (level > 0) {
      if (!context.mounted) return;
      pin = await showPinSetupDialog(
        context: context,
        title: '设置用户「${nameCtrl.text.trim()}」的 PIN 码',
      );
      if (pin == null) return;
    }

    await ref.read(appControllerProvider.notifier).createUser(
          name: nameCtrl.text.trim(),
          authLevel: level,
          pin: pin,
        );
  }

  Future<void> _editUser(
    BuildContext context,
    WidgetRef ref,
    UserAccount target,
  ) async {
    // Enforces cross-user anti-escalation rule!
    final authorized = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
      targetUser: target,
      reason: '修改用户「${target.name}」的资料与安全级别需要验证该用户 PIN 码或超级管理员主 PIN 码',
    );
    if (!authorized || !context.mounted) return;

    final nameCtrl = TextEditingController(text: target.name);
    int level = target.authLevel;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('编辑用户「${target.name}」'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: level,
                decoration: const InputDecoration(
                  labelText: '安全保护级别',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('级别 0：无密码（打开即用）')),
                  DropdownMenuItem(value: 1, child: Text('级别 1：删改保护')),
                  DropdownMenuItem(value: 2, child: Text('级别 2：增删改保护')),
                  DropdownMenuItem(value: 3, child: Text('级别 3：增删改查全保护')),
                ],
                onChanged: (v) => setState(() => level = v ?? 0),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    UserAccount updated = target.copyWith(
      name: nameCtrl.text.trim(),
      authLevel: level,
    );

    if (level == 0) {
      updated = updated.copyWith(clearPin: true);
    } else if (target.pinHash == null || target.pinHash!.isEmpty) {
      if (!context.mounted) return;
      final newPin = await showPinSetupDialog(
        context: context,
        title: '为「${updated.name}」设置 PIN 码',
      );
      if (newPin == null) return;
      final salt = PinCrypto.generateSalt();
      updated = updated.copyWith(
        pinSalt: salt,
        pinHash: PinCrypto.hashPin(newPin, salt),
      );
    }

    await ref.read(appControllerProvider.notifier).updateUser(updated);
  }

  Future<void> _resetUserPinWithMaster(
    BuildContext context,
    WidgetRef ref,
    UserAccount target,
  ) async {
    final verified = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.masterOnly,
      reason: '重置用户「${target.name}」的 PIN 码需要验证超级管理员主 PIN 码（账单数据将完整保留）',
    );
    if (!verified || !context.mounted) return;

    final newPin = await showPinSetupDialog(
      context: context,
      title: '为用户「${target.name}」设置新 PIN 码',
    );
    if (newPin == null) return;

    final salt = PinCrypto.generateSalt();
    final updated = target.copyWith(
      authLevel: target.authLevel == 0 ? 1 : target.authLevel,
      pinSalt: salt,
      pinHash: PinCrypto.hashPin(newPin, salt),
    );
    await ref.read(appControllerProvider.notifier).updateUser(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已重置「${target.name}」的 PIN 码，账单数据完好无损')),
      );
    }
  }

  Future<void> _deleteUser(
    BuildContext context,
    WidgetRef ref,
    UserAccount target,
  ) async {
    final users = ref.read(appControllerProvider).users;
    if (users.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少需要保留一个用户')),
      );
      return;
    }

    final authorized = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
      targetUser: target,
      reason: '删除用户「${target.name}」及其名下所有账单需要验证该用户 PIN 码或超级管理员主 PIN 码',
    );
    if (!authorized || !context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除用户确认'),
        content: Text('确定删除用户「${target.name}」吗？该用户的全部账单与 AI 对话历史将被永久删除！'),
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
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await ref.read(appControllerProvider.notifier).deleteUser(target.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final currentId = state.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('多用户与安全权限管理'),
        actions: [
          IconButton(
            tooltip: '新增用户',
            onPressed: () => _addUser(context, ref),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF4F46E5),
                child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
              ),
              title: const Text(
                '超级管理员主密码',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                '用于解锁子用户、重置密码及整机备份',
                style: TextStyle(fontSize: 12),
              ),
              trailing: FilledButton.tonal(
                onPressed: () => _changeMasterPin(context, ref),
                child: const Text('修改主码'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '本地用户列表 (${state.users.length})',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...state.users.map((u) {
            final isCurrent = u.id == currentId;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          child: Text(
                            u.name.isNotEmpty ? u.name.substring(0, 1) : '?',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    u.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isCurrent) ...[
                                    const SizedBox(width: 6),
                                    const Chip(
                                      label: Text('当前活跃', style: TextStyle(fontSize: 10.5)),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                u.authLevelLabel,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _editUser(context, ref, u),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('改名/权限'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _resetUserPinWithMaster(context, ref, u),
                          icon: const Icon(Icons.lock_reset_rounded, size: 16),
                          label: const Text('忘记/重置 PIN'),
                        ),
                        if (state.users.length > 1)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () => _deleteUser(context, ref, u),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('删除用户'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
