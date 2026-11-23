import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/ai_models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/pin_dialog.dart';
import '../insights/llm_config_dialog.dart';

class LlmProfilesScreen extends ConsumerWidget {
  static const _uuid = Uuid();
  const LlmProfilesScreen({super.key});

  Future<void> _addOrEdit(
    BuildContext context,
    WidgetRef ref, {
    LlmProfile? existing,
  }) async {
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
      reason: '新增或修改大模型 API 配置需要验证权限',
    );
    if (!ok || !context.mounted) return;

    final result = await showLlmProfileEditorDialog(
      context,
      existing: existing,
    );
    if (result == null) return;

    final current =
        List<LlmProfile>.from(ref.read(appControllerProvider).settings.llmProfiles);
    String? newActiveId;
    if (existing == null) {
      current.add(result);
      newActiveId = result.id;
    } else {
      final idx = current.indexWhere((p) => p.id == existing.id);
      if (idx != -1) {
        current[idx] = result;
      }
    }
    await ref.read(appControllerProvider.notifier).saveLlmProfiles(
          current,
          activeProfileId: newActiveId,
        );
  }

  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    LlmProfile src,
  ) async {
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
    );
    if (!ok) return;

    final current =
        List<LlmProfile>.from(ref.read(appControllerProvider).settings.llmProfiles);
    current.add(
      src.copyWith(
        id: 'llm_${_uuid.v4().substring(0, 8)}',
        name: '${src.name} 副本',
      ),
    );
    await ref.read(appControllerProvider.notifier).saveLlmProfiles(current);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    LlmProfile target,
  ) async {
    final current = ref.read(appControllerProvider).settings.llmProfiles;
    if (current.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少需要保留 1 套 API 配置')),
      );
      return;
    }
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
    );
    if (!ok) return;

    final next = current.where((p) => p.id != target.id).toList();
    await ref.read(appControllerProvider.notifier).saveLlmProfiles(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appControllerProvider).settings;
    final profiles = settings.llmProfiles;
    final activeId = settings.activeLlmProfile.id;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('大模型 API 配置'),
        actions: [
          IconButton(
            tooltip: '新建配置',
            onPressed: () => _addOrEdit(context, ref),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: profiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final p = profiles[i];
          final isActive = p.id == activeId;

          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isActive
                  ? BorderSide(color: cs.primary, width: 2)
                  : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Chip(
                                  label: Text(
                                    p.apiFormat.shortBadge,
                                    style: const TextStyle(fontSize: 10.5),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '模型：${p.modelName}',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            Text(
                              p.baseUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isActive)
                        const Chip(
                          avatar: Icon(Icons.check_circle, size: 16),
                          label: Text('已启用'),
                        )
                      else
                        FilledButton.tonal(
                          onPressed: () => ref
                              .read(appControllerProvider.notifier)
                              .selectActiveLlmProfile(p.id),
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
                        onPressed: () => _addOrEdit(context, ref, existing: p),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('编辑'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _duplicate(context, ref, p),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('复制'),
                      ),
                      if (profiles.length > 1)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.error,
                          ),
                          onPressed: () => _delete(context, ref, p),
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
