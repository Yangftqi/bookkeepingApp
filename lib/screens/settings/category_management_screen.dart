import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/category.dart';
import '../../providers/app_providers.dart';
import '../../utils/color_utils.dart';
import '../../widgets/pin_dialog.dart';

class CategoryManagementScreen extends ConsumerWidget {
  static const _uuid = Uuid();
  const CategoryManagementScreen({super.key});

  Future<void> _addOrEditCategory(
    BuildContext context,
    WidgetRef ref, {
    ExpenseCategory? existing,
  }) async {
    if (existing != null && existing.isUncategorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('系统常驻「未分类」禁止改名或删除，可在主题工坊自定义其颜色与背景图')),
      );
      return;
    }

    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
      reason: '新增或修改全局支出类别需要验证权限',
    );
    if (!ok || !context.mounted) return;

    final allCats = ref.read(appControllerProvider).categories;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String selectedColorHex = existing?.defaultColorHex ??
        ColorUtils.defaultCategoryPalette[
            allCats.length % ColorUtils.defaultCategoryPalette.length];

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? '新建全局支出类别' : '编辑类别「${existing.name}」'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '类别名称（全局唯一）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('默认兜底主题色：', style: TextStyle(fontSize: 12.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ColorUtils.defaultCategoryPalette.map((hex) {
                  final color = ColorUtils.fromHex(hex);
                  final isSelected = selectedColorHex == hex;
                  return GestureDetector(
                    onTap: () => setState(() => selectedColorHex = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black87, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
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
                final trimmed = nameCtrl.text.trim();
                if (trimmed.isEmpty) return;
                final dup = allCats.any(
                  (c) => c.name == trimmed && c.id != existing?.id,
                );
                if (dup) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('已存在同名类别，请更换名称')),
                  );
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

    final cat = ExpenseCategory(
      id: existing?.id ?? 'cat_${_uuid.v4()}',
      name: nameCtrl.text.trim(),
      isUncategorized: false,
      defaultColorHex: selectedColorHex,
      sortOrder: existing?.sortOrder ?? allCats.length,
    );
    await ref.read(appControllerProvider.notifier).saveCategory(cat);
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    ExpenseCategory cat,
  ) async {
    if (cat.isUncategorized) return;
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
      reason: '删除全局支出类别需要验证权限',
    );
    if (!ok || !context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除类别「${cat.name}」'),
        content: const Text(
          '删除后，全软件所有用户该类别下的历史账单将自动安全归入「未分类」，不会丢失任何账单金额。确定继续吗？',
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
            child: const Text('确认删除并迁移'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(appControllerProvider.notifier).deleteCategory(cat.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final themeCfg = state.activeTheme.config;

    return Scaffold(
      appBar: AppBar(
        title: const Text('全局支出类别管理'),
        actions: [
          IconButton(
            tooltip: '说明',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('类别管理说明'),
                  content: const Text(
                    '• 「未分类」为系统常驻兜底类别，不可改名或删除，但可在主题工坊自定义其颜色与卡片底图。\n'
                    '• 重命名任意类别后，已保存主题中为该类别配置的背景图与主题色均会自动保留。\n'
                    '• 删除某类别时，该类别下的历史账单会自动转入「未分类」。',
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
          IconButton(
            tooltip: '新增类别',
            onPressed: () => _addOrEditCategory(context, ref),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: state.categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final cat = state.categories[i];
          final style = themeCfg.styleForCategory(
            categoryId: cat.id,
            categoryName: cat.name,
            defaultColorHex: cat.defaultColorHex,
          );
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: style.color,
                child: Icon(
                  cat.isUncategorized
                      ? Icons.inbox_rounded
                      : Icons.label_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              title: Text(
                cat.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: cat.isUncategorized
                  ? const Text('系统默认兜底类别', style: TextStyle(fontSize: 12))
                  : null,
              trailing: cat.isUncategorized
                  ? const Chip(
                      label: Text('常驻', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: () => _addOrEditCategory(
                            context,
                            ref,
                            existing: cat,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 19,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => _deleteCategory(context, ref, cat),
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
