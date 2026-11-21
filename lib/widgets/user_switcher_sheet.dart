import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_account.dart';
import '../providers/app_providers.dart';
import 'pin_dialog.dart';

Future<void> showUserSwitcherSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => const _UserSwitcherSheet(),
  );
}

class _UserSwitcherSheet extends ConsumerWidget {
  const _UserSwitcherSheet();

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

  Future<void> _selectUser(
    BuildContext context,
    WidgetRef ref,
    UserAccount target,
  ) async {
    final controller = ref.read(appControllerProvider.notifier);
    if (target.authLevel >= 3) {
      final verified = await showPinVerifyDialog(
        context: context,
        title: '进入用户「${target.name}」',
        subtitle: '该用户已开启增删改查全保护，请输入其 PIN 码或超级管理员主 PIN 码',
        validator: (pin) => controller.verifyUserOrMasterPin(pin, target),
      );
      if (!verified) return;
      await controller.switchUser(target.id, alreadyVerified: true);
    } else {
      await controller.switchUser(target.id, alreadyVerified: false);
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _quickCreateUser(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    int selectedLevel = 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('新建记账用户'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  hintText: '例如：个人账本、家庭公账',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: selectedLevel,
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
                onChanged: (v) => setState(() => selectedLevel = v ?? 0),
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
              child: const Text('下一步'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    String? pin;
    if (selectedLevel > 0) {
      if (!context.mounted) return;
      pin = await showPinSetupDialog(
        context: context,
        title: '为「$name」设置 PIN 码',
        subtitle: '请设置 4~6 位数字密码',
      );
      if (pin == null) return;
    }

    final controller = ref.read(appControllerProvider.notifier);
    final newUser = await controller.createUser(
      name: name,
      authLevel: selectedLevel,
      pin: pin,
    );
    await controller.switchUser(
      newUser.id,
      alreadyVerified: selectedLevel >= 3,
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final currentId = state.currentUser?.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '切换记账用户',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _quickCreateUser(context, ref),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('新建用户'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: state.users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final u = state.users[i];
                  final isCurrent = u.id == currentId;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(_levelIcon(u.authLevel), size: 20),
                    ),
                    title: Text(
                      u.name,
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(u.authLevelLabel),
                    trailing: isCurrent
                        ? const Chip(
                            label: Text('当前', style: TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: isCurrent
                        ? () => Navigator.of(context).pop()
                        : () => _selectUser(context, ref, u),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
