import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../models/economic_models.dart';
import '../../providers/app_providers.dart';
import '../../utils/date_utils_ext.dart';
import '../../widgets/pin_dialog.dart';
import 'economics_api_dialog.dart';
import 'economics_manage_screen.dart';

enum _EconPeriod { thisMonth, last3Months, thisYear, all, custom }

class _RankedRow {
  final String name;
  final double value;
  final String note;
  final bool isMe;

  const _RankedRow({
    required this.name,
    required this.value,
    required this.note,
    this.isMe = false,
  });
}

class EconomicsCompareView extends ConsumerStatefulWidget {
  const EconomicsCompareView({super.key});

  @override
  ConsumerState<EconomicsCompareView> createState() =>
      _EconomicsCompareViewState();
}

class _EconomicsCompareViewState extends ConsumerState<EconomicsCompareView> {
  String? _selectedMetricId;
  _EconPeriod _period = _EconPeriod.thisMonth;
  DateTimeRange? _customRange;
  bool _useManualBase = false;
  final TextEditingController _manualBaseCtrl =
      TextEditingController(text: '5000');
  final Set<String> _selectedNumeratorCatIds = {};
  String? _initializedMetricForChips;

  @override
  void dispose() {
    _manualBaseCtrl.dispose();
    super.dispose();
  }

  void _syncSuggestedCategories(
    EconomicMetric metric,
    List<ExpenseCategory> categories,
  ) {
    if (_initializedMetricForChips == metric.id) return;
    _initializedMetricForChips = metric.id;
    _selectedNumeratorCatIds.clear();
    _useManualBase = metric.denominatorType == 'manual_base';

    for (final cat in categories) {
      final lower = cat.name.toLowerCase();
      for (final kw in metric.suggestedCategoryKeywords) {
        if (kw.isNotEmpty && lower.contains(kw.toLowerCase())) {
          _selectedNumeratorCatIds.add(cat.id);
          break;
        }
      }
    }
    if (_selectedNumeratorCatIds.isEmpty && categories.isNotEmpty) {
      _selectedNumeratorCatIds.add(categories.first.id);
    }
  }

  (DateTime, DateTime, String) _dateBounds() {
    final now = DateTime.now();
    switch (_period) {
      case _EconPeriod.thisMonth:
        return (
          DateUtilsExt.startOfMonth(now),
          DateUtilsExt.endOfMonth(now),
          '本月'
        );
      case _EconPeriod.last3Months:
        final s = DateTime(now.year, now.month - 2, 1);
        return (s, DateUtilsExt.endOfDay(now), '近 3 个月');
      case _EconPeriod.thisYear:
        return (DateTime(now.year, 1, 1), DateUtilsExt.endOfDay(now), '今年');
      case _EconPeriod.all:
        return (DateTime(2000, 1, 1), DateUtilsExt.endOfDay(now), '全部时间');
      case _EconPeriod.custom:
        if (_customRange != null) {
          final s = DateUtilsExt.startOfDay(_customRange!.start);
          final e = DateUtilsExt.endOfDay(_customRange!.end);
          return (
            s,
            e,
            '${DateUtilsExt.toDateStr(s)} ~ ${DateUtilsExt.toDateStr(e)}'
          );
        }
        return (
          DateUtilsExt.startOfMonth(now),
          DateUtilsExt.endOfMonth(now),
          '本月'
        );
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _period = _EconPeriod.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final g = state.activeTheme.config.globalStyle;
    final currency = state.settings.displayCurrency;
    final metrics = state.economicMetrics;

    if (metrics.isEmpty) {
      return Center(
        child: Text(
          '暂无经济学模型',
          style: TextStyle(color: g.secondaryTextColor),
        ),
      );
    }

    final currentMetric = metrics.firstWhere(
      (m) => m.id == _selectedMetricId,
      orElse: () => metrics.first,
    );
    _selectedMetricId = currentMetric.id;
    _syncSuggestedCategories(currentMetric, state.categories);

    final benchmarks = state.benchmarksByMetric[currentMetric.id] ?? const [];
    final tiers = benchmarks.where((b) => b.isTierStandard).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final samples = benchmarks.where((b) => !b.isTierStandard).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final (start, end, periodName) = _dateBounds();
    final filteredExpenses = state.expenses.where((e) {
      return e.timestamp >= start.millisecondsSinceEpoch &&
          e.timestamp <= end.millisecondsSinceEpoch;
    }).toList();

    final totalExpense =
        filteredExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final numeratorAmount = filteredExpenses
        .where((e) => _selectedNumeratorCatIds.contains(e.categoryId))
        .fold<double>(0.0, (sum, e) => sum + e.amount);

    final manualBase = double.tryParse(_manualBaseCtrl.text.trim()) ?? 0.0;
    final denominator = _useManualBase ? manualBase : totalExpense;
    final myPct = denominator > 0
        ? (numeratorAmount / denominator * 100.0).clamp(0.0, 999.9)
        : 0.0;

    // Match tier standard
    EconomicBenchmark? matchedTier;
    if (denominator > 0) {
      for (final t in tiers) {
        final upper = t.maxValue ?? 100.0;
        if (myPct >= t.value && (myPct < upper || (upper >= 100 && myPct <= 100))) {
          matchedTier = t;
          break;
        }
      }
      if (matchedTier == null && tiers.isNotEmpty) {
        matchedTier = myPct >= (tiers.last.value) ? tiers.last : tiers.first;
      }
    }

    // Calculate percentile from low to high
    double? percentile;
    if (denominator > 0 && samples.isNotEmpty) {
      final lowerCount = samples.where((s) => s.value < myPct).length;
      final equalCount = samples.where((s) => s.value == myPct).length;
      percentile =
          ((lowerCount + equalCount * 0.5) / samples.length * 100.0)
              .clamp(0.0, 100.0);
    }

    // Build combined horizontal comparison list inserting "★ 我的当前水平"
    final rankedRows = <_RankedRow>[
      ...samples.map(
        (s) => _RankedRow(name: s.name, value: s.value, note: s.note),
      ),
      if (denominator > 0)
        _RankedRow(
          name: '★ 我的当前水平 (${myPct.toStringAsFixed(1)}%)',
          value: myPct,
          note: matchedTier?.name ?? '当前选定时间段',
          isMe: true,
        ),
    ]..sort((a, b) => a.value.compareTo(b.value));

    final maxBarVal = rankedRows.fold<double>(
      10.0,
      (m, r) => max(m, r.value),
    );

    final selectedCatNames = state.categories
        .where((c) => _selectedNumeratorCatIds.contains(c.id))
        .map((c) => c.name)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
      children: [
        // Metric Selector + API Model Generator + Manage Library
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: g.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: currentMetric.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '经济学模型',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: metrics
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(
                                m.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        if (id == null) return;
                        setState(() {
                          _selectedMetricId = id;
                          _initializedMetricForChips = null;
                        });
                      },
                    ),
                  ),
                  if (currentMetric.description.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: '指标说明',
                      icon: Icon(
                        Icons.info_outline_rounded,
                        color: g.secondaryTextColor,
                      ),
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(currentMetric.name),
                            content: Text(currentMetric.description),
                            actions: [
                              FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('知道了'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final ok = await AuthGuard.requireAction(
                        context,
                        ref,
                        ProtectedAction.modifyOrDelete,
                        reason: '通过 API 拉取或生成新的经济学统计模型需要验证权限',
                      );
                      if (!ok || !context.mounted) return;
                      final newMetricId = await showEconomicsApiDialog(context, ref);
                      if (newMetricId != null && mounted) {
                        setState(() {
                          _selectedMetricId = newMetricId;
                          _initializedMetricForChips = null;
                        });
                      }
                    },
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('API 一键拉取/生成模型'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EconomicsManageScreen(
                            initialMetricId: currentMetric.id,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('管理基准库'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Time range + Denominator + Numerator Categories
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: g.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '统计时段 ($periodName)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: g.textColor,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in {
                    _EconPeriod.thisMonth: '本月',
                    _EconPeriod.last3Months: '近3月',
                    _EconPeriod.thisYear: '今年',
                    _EconPeriod.all: '全部',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _period == entry.key,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _period = entry.key),
                    ),
                  ChoiceChip(
                    label: Text(
                      _period == _EconPeriod.custom ? periodName : '自定义',
                    ),
                    selected: _period == _EconPeriod.custom,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => _pickCustomRange(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '分子类别',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: g.textColor,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: state.categories.map((cat) {
                  final selected = _selectedNumeratorCatIds.contains(cat.id);
                  return FilterChip(
                    label: Text(cat.name),
                    selected: selected,
                    visualDensity: VisualDensity.compact,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedNumeratorCatIds.add(cat.id);
                      } else {
                        _selectedNumeratorCatIds.remove(cat.id);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                '分母基准',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: g.textColor,
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('所选时段总支出')),
                  ButtonSegment(value: true, label: Text('手动输入基数')),
                ],
                selected: {_useManualBase},
                onSelectionChanged: (s) =>
                    setState(() => _useManualBase = s.first),
              ),
              if (_useManualBase) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _manualBaseCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '当期基数金额（如可支配收入 / 总预算）',
                    prefixText: currency,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Result + Tier Standard + Percentile + One-Click AI Interpretation
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: g.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: g.primary.withOpacity(0.35), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '我的${currentMetric.name}',
                        style: TextStyle(
                          fontSize: 13,
                          color: g.secondaryTextColor,
                        ),
                      ),
                      Text(
                        denominator > 0
                            ? '${myPct.toStringAsFixed(1)}%'
                            : '暂无数据',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: g.primary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (percentile != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: g.primary.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '样本库从低到高',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: g.secondaryTextColor,
                            ),
                          ),
                          Text(
                            '前 ${percentile.toStringAsFixed(1)}% 分位',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: g.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '分子（${selectedCatNames.join("、")}）：$currency${numeratorAmount.toStringAsFixed(2)}  ÷  分母：$currency${denominator.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: g.secondaryTextColor),
              ),
              if (matchedTier != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '标准评级定位：${matchedTier.name}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: g.textColor,
                        ),
                      ),
                      if (matchedTier.note.isNotEmpty)
                        Text(
                          matchedTier.note,
                          style: TextStyle(
                            fontSize: 12,
                            color: g.secondaryTextColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: g.primary),
                  onPressed: () {
                    final snapshot = EconomicComparisonSnapshot(
                      metricName: currentMetric.name,
                      myValuePercent: myPct,
                      matchedTierName: matchedTier?.name,
                      matchedTierNote: matchedTier?.note,
                      percentileFromLow: percentile,
                      totalSamples: samples.length,
                      selectedCategoryNames: selectedCatNames,
                      numeratorAmount: numeratorAmount,
                      denominatorAmount: denominator,
                    );
                    final prompt =
                        '请深度解读我当前在「${currentMetric.name}」经济学模型下的表现：\n'
                        '- 统计时段：$periodName (${DateUtilsExt.toDateStr(start)} 至 ${DateUtilsExt.toDateStr(end)})\n'
                        '- 分子类别：${selectedCatNames.join("、")} ($currency${numeratorAmount.toStringAsFixed(2)})\n'
                        '- 分母金额：$currency${denominator.toStringAsFixed(2)} (${_useManualBase ? "手动输入基数" : "时段总支出"})\n'
                        '- 我的指标值：${myPct.toStringAsFixed(1)}%\n'
                        '- 所处标准评级区间：${matchedTier?.name ?? "无"} (${matchedTier?.note ?? ""})\n'
                        '- 在 ${samples.length} 个国家/地区/群体样本中（从低到高）处于前 ${percentile?.toStringAsFixed(1) ?? "N/A"}% 分位。\n'
                        '请结合我该时间段的整体支出结构给出专业点评和可执行优化建议！';

                    ref
                        .read(appControllerProvider.notifier)
                        .triggerOneClickAiAnalysis(
                          PendingAiAnalysisRequest(
                            title: '${currentMetric.name} 深度解读',
                            contextPrompt: prompt,
                            startDate: start,
                            endDate: end,
                            economicSnapshot: snapshot,
                          ),
                        );
                  },
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text(
                    '一键交给 AI 深度解读',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Horizontal Comparative Ranking Chart
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: g.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '基准排行 (${samples.length})',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: g.textColor,
                      ),
                    ),
                  ),
                  Text(
                    '低 → 高',
                    style: TextStyle(fontSize: 11.5, color: g.secondaryTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...rankedRows.map((row) {
                final ratio = (row.value / maxBarVal).clamp(0.02, 1.0);
                final barColor =
                    row.isMe ? const Color(0xFFF59E0B) : g.primary.withOpacity(0.7);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(row.isMe ? 8 : 2),
                  decoration: row.isMe
                      ? BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFF59E0B),
                            width: 1.4,
                          ),
                        )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.name,
                              style: TextStyle(
                                fontSize: row.isMe ? 13.5 : 12.5,
                                fontWeight: row.isMe
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: row.isMe
                                    ? const Color(0xFFB45309)
                                    : g.textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${row.value.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: row.isMe ? 13.5 : 12,
                              fontWeight: FontWeight.w800,
                              color: row.isMe
                                  ? const Color(0xFFB45309)
                                  : g.textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: row.isMe ? 10 : 6,
                          color: barColor,
                          backgroundColor: barColor.withOpacity(0.15),
                        ),
                      ),
                      if (row.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            row.note,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: g.secondaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
