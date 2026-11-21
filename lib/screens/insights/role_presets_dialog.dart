import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/seed_data.dart';
import '../../models/ai_models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/pin_dialog.dart';

Future<void> showRolePresetsDialog(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => const _RolePresetsDialog(),
  );
}

class _RolePresetsDialog extends ConsumerWidget {
  static const _uuid = Uuid();
  const _RolePresetsDialog();

  Future<void> _editRole(
    BuildContext context,
    WidgetRef ref, {
    AiRolePreset? existing,
  }) async {
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
      reason: '新增或编辑 AI 角色预设需要验证权限',
    );
    if (!ok || !context.mounted) return;

    final templates = SeedData.defaultAiRolePresets();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final taglineCtrl = TextEditingController(text: existing?.tagline ?? '');
    final promptCtrl =
        TextEditingController(text: existing?.systemPrompt ?? '');
    String? selectedTemplateId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? '新增角色预设' : '编辑角色预设'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedTemplateId,
                    isExpanded: true,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: '套用系统预置模板（选填，可快速找回或基于模板修改）',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.auto_fix_high_rounded, size: 18),
                    ),
                    items: templates
                        .map(
                          (tpl) => DropdownMenuItem(
                            value: tpl.id,
                            child: Text(
                              '${tpl.name}（${tpl.tagline}）',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (tplId) {
                      if (tplId == null) return;
                      final tpl =
                          templates.firstWhere((e) => e.id == tplId);
                      setState(() {
                        selectedTemplateId = tplId;
                        nameCtrl.text = tpl.name;
                        taglineCtrl.text = tpl.tagline;
                        promptCtrl.text = tpl.systemPrompt;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '角色名称',
                      hintText: '如：理性经济学家、同居粘人猫娘',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: taglineCtrl,
                    decoration: const InputDecoration(
                      labelText: '特色说明（简短关键词，留空则显示设定摘要）',
                      hintText: '如：严谨 客观 经济学家',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: promptCtrl,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: '角色设定 (System Prompt)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty ||
                    promptCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final currentList = List<AiRolePreset>.from(
      ref.read(appControllerProvider).settings.aiRolePresets,
    );
    if (existing == null) {
      currentList.add(
        AiRolePreset(
          id: 'role_${_uuid.v4()}',
          name: nameCtrl.text.trim(),
          tagline: taglineCtrl.text.trim(),
          systemPrompt: promptCtrl.text.trim(),
          isBuiltin: false,
        ),
      );
    } else {
      final idx = currentList.indexWhere((r) => r.id == existing.id);
      if (idx != -1) {
        currentList[idx] = existing.copyWith(
          name: nameCtrl.text.trim(),
          tagline: taglineCtrl.text.trim(),
          systemPrompt: promptCtrl.text.trim(),
        );
      }
    }
    await ref
        .read(appControllerProvider.notifier)
        .updateAiRolePresets(currentList);
  }

  Future<void> _restoreMissingTemplates(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
    );
    if (!ok || !context.mounted) return;

    final current = List<AiRolePreset>.from(
      ref.read(appControllerProvider).settings.aiRolePresets,
    );
    final existingNames = current.map((e) => e.name).toSet();
    int added = 0;
    for (final tpl in SeedData.defaultAiRolePresets()) {
      if (!existingNames.contains(tpl.name)) {
        current.add(tpl);
        added++;
      }
    }
    await ref.read(appControllerProvider.notifier).updateAiRolePresets(current);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added > 0 ? '已找回 $added 个系统预置角色' : '所有系统预置角色均已在列表中',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(appControllerProvider).settings.aiRolePresets;
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('AI 角色预设')),
          IconButton(
            tooltip: '找回缺失的预置角色',
            onPressed: () => _restoreMissingTemplates(context, ref),
            icon: const Icon(Icons.restore_rounded),
          ),
          IconButton(
            tooltip: '新增角色',
            onPressed: () => _editRole(context, ref),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        height: 380,
        child: ListView.separated(
          itemCount: presets.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final r = presets[i];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(
                r.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                r.displayTagline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '编辑',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _editRole(context, ref, existing: r),
                  ),
                  IconButton(
                    tooltip: '删除',
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () async {
                      if (presets.length <= 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('至少需要保留 1 个角色预设')),
                        );
                        return;
                      }
                      final ok = await AuthGuard.requireAction(
                        context,
                        ref,
                        ProtectedAction.modifyOrDelete,
                      );
                      if (!ok) return;
                      final next =
                          presets.where((p) => p.id != r.id).toList();
                      await ref
                          .read(appControllerProvider.notifier)
                          .updateAiRolePresets(next);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }
}
