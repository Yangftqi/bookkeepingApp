import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/economic_models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/pin_dialog.dart';

class EconomicsManageScreen extends ConsumerStatefulWidget {
  final String? initialMetricId;
  const EconomicsManageScreen({super.key, this.initialMetricId});

  @override
  ConsumerState<EconomicsManageScreen> createState() =>
      _EconomicsManageScreenState();
}

class _EconomicsManageScreenState extends ConsumerState<EconomicsManageScreen> {
  static const _uuid = Uuid();
  String? _selectedMetricId;

  @override
  void initState() {
    super.initState();
    _selectedMetricId = widget.initialMetricId;
  }

  Future<void> _createOrEditMetric({EconomicMetric? existing}) async {
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
    );
    if (!ok || !mounted) return;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final kwCtrl = TextEditingController(
      text: existing?.suggestedCategoryKeywords.join(',') ?? '',
    );
    String denomType = existing?.denominatorType ?? 'total_expense';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? '新建经济学指标模型' : '编辑指标模型'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '指标名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '经济学定义与说明',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: kwCtrl,
                  decoration: const InputDecoration(
                    labelText: '推荐分子类别关键词（逗号分隔）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: denomType,
                  decoration: const InputDecoration(
                    labelText: '默认分母模式',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'total_expense',
                      child: Text('所选时段账单总支出'),
                    ),
                    DropdownMenuItem(
                      value: 'manual_base',
                      child: Text('手动输入基数金额'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => denomType = v ?? 'total_expense'),
                ),
              ],
            ),
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

    if (saved != true) return;
    final keywords = kwCtrl.text
        .split(RegExp(r'[,，、\s]+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();

    final metric = EconomicMetric(
      id: existing?.id ?? 'metric_${_uuid.v4()}',
      name: nameCtrl.text.trim(),
      description: descCtrl.text.trim(),
      denominatorType: denomType,
      suggestedCategoryKeywords: keywords,
      isBuiltin: existing?.isBuiltin ?? false,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.read(appControllerProvider.notifier).saveEconomicModel(
          metric,
          const [],
          replaceBenchmarks: false,
        );
    setState(() => _selectedMetricId = metric.id);
  }

  Future<void> _addOrEditBenchmark(
    String metricId, {
    EconomicBenchmark? existing,
    required bool isTier,
  }) async {
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
    );
    if (!ok || !mounted) return;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final valCtrl = TextEditingController(
      text: existing != null ? existing.value.toString() : '',
    );
    final maxValCtrl = TextEditingController(
      text: existing?.maxValue != null ? existing!.maxValue.toString() : '',
    );
    final noteCtrl = TextEditingController(text: existing?.note ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing == null
              ? (isTier ? '新增评级区间' : '新增对比样本')
              : (isTier ? '编辑评级区间' : '编辑对比样本'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: isTier ? '区间名称' : '国家/地区/群体名称',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: valCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isTier ? '区间下限 (%)' : '百分比数值 (%)',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (isTier) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: maxValCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '区间上限 (%)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: '说明 / 数据来源',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
                  double.tryParse(valCtrl.text.trim()) == null) {
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved != true) return;

    final bench = EconomicBenchmark(
      id: existing?.id ?? 'bench_${_uuid.v4()}',
      metricId: metricId,
      name: nameCtrl.text.trim(),
      isTierStandard: isTier,
      value: double.parse(valCtrl.text.trim()),
      maxValue: isTier ? (double.tryParse(maxValCtrl.text.trim()) ?? 100.0) : null,
      note: noteCtrl.text.trim(),
    );
    await ref.read(appControllerProvider.notifier).upsertBenchmark(bench);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final metrics = state.economicMetrics;
    final current = metrics.firstWhere(
      (m) => m.id == _selectedMetricId,
      orElse: () => metrics.first,
    );
    _selectedMetricId = current.id;
    final benches = state.benchmarksByMetric[current.id] ?? const [];
    final tiers = benches.where((b) => b.isTierStandard).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final samples = benches.where((b) => !b.isTierStandard).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('经济学模型与基准库管理'),
        actions: [
          IconButton(
            tooltip: '新建指标模型',
            onPressed: () => _createOrEditMetric(),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: current.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '选择要管理的指标模型',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: metrics
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (id) => setState(() => _selectedMetricId = id),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '编辑该模型信息',
                onPressed: () => _createOrEditMetric(existing: current),
                icon: const Icon(Icons.edit_outlined),
              ),
              if (!current.isBuiltin)
                IconButton(
                  tooltip: '删除该自定义模型',
                  onPressed: () async {
                    final ok = await AuthGuard.requireAction(
                      context,
                      ref,
                      ProtectedAction.modifyOrDelete,
                    );
                    if (!ok) return;
                    await ref
                        .read(appControllerProvider.notifier)
                        .deleteEconomicMetric(current.id);
                    setState(() => _selectedMetricId = null);
                  },
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Tiers section
          Row(
            children: [
              Text(
                '标准评级区间 (${tiers.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addOrEditBenchmark(current.id, isTier: true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增区间'),
              ),
            ],
          ),
          ...tiers.map(
            (t) => Card(
              child: ListTile(
                title: Text(t.name),
                subtitle: Text(
                  '${t.value}% ~ ${t.maxValue ?? 100}%  ${t.note}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _addOrEditBenchmark(
                        current.id,
                        existing: t,
                        isTier: true,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () async {
                        final ok = await AuthGuard.requireAction(
                          context,
                          ref,
                          ProtectedAction.modifyOrDelete,
                        );
                        if (!ok) return;
                        await ref
                            .read(appControllerProvider.notifier)
                            .deleteBenchmark(t.id);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          // Samples section
          Row(
            children: [
              Text(
                '国家/地区/群体对比样本 (${samples.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addOrEditBenchmark(current.id, isTier: false),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增样本'),
              ),
            ],
          ),
          ...samples.map(
            (s) => Card(
              child: ListTile(
                title: Text(s.name),
                subtitle: Text(s.note),
                leading: CircleAvatar(
                  radius: 22,
                  child: Text(
                    '${s.value.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _addOrEditBenchmark(
                        current.id,
                        existing: s,
                        isTier: false,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () async {
                        final ok = await AuthGuard.requireAction(
                          context,
                          ref,
                          ProtectedAction.modifyOrDelete,
                        );
                        if (!ok) return;
                        await ref
                            .read(appControllerProvider.notifier)
                            .deleteBenchmark(s.id);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
