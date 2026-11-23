import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expense.dart';
import '../../providers/app_providers.dart';
import '../../utils/date_utils_ext.dart';
import '../../widgets/expense_card.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/pin_dialog.dart';
import 'expense_editor_sheet.dart';

enum _DateRangePreset { all, today, thisWeek, thisMonth, custom }

enum _DayTypeFilter { all, workday, restDay }

enum _ExpenseSort { timeDesc, timeAsc, amountDesc, amountAsc }

class BillsTab extends ConsumerStatefulWidget {
  const BillsTab({super.key});

  @override
  ConsumerState<BillsTab> createState() => _BillsTabState();
}

class _BillsTabState extends ConsumerState<BillsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _keyword = '';
  _DateRangePreset _datePreset = _DateRangePreset.all;
  DateTimeRange? _customRange;
  final Set<String> _selectedCategoryIds = {};
  _DayTypeFilter _dayTypeFilter = _DayTypeFilter.all;
  _ExpenseSort _sort = _ExpenseSort.timeDesc;
  bool _showFilters = false;

  bool _batchMode = false;
  final Set<String> _selectedExpenseIds = {};

  /// Minimalist translucent list mode (hides per-card background images to showcase global background).
  bool _minimalistMode = false;

  /// Pure background appreciation overlay (hides foreground UI until tapped).
  bool _artPreviewMode = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Expense> _applyFilter(List<Expense> all) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    switch (_datePreset) {
      case _DateRangePreset.all:
        break;
      case _DateRangePreset.today:
        start = DateUtilsExt.startOfDay(now);
        end = DateUtilsExt.endOfDay(now);
        break;
      case _DateRangePreset.thisWeek:
        start = DateUtilsExt.startOfWeek(now);
        end = DateUtilsExt.endOfWeek(now);
        break;
      case _DateRangePreset.thisMonth:
        start = DateUtilsExt.startOfMonth(now);
        end = DateUtilsExt.endOfMonth(now);
        break;
      case _DateRangePreset.custom:
        if (_customRange != null) {
          start = DateUtilsExt.startOfDay(_customRange!.start);
          end = DateUtilsExt.endOfDay(_customRange!.end);
        }
        break;
    }

    final kw = _keyword.trim().toLowerCase();
    final filtered = all.where((e) {
      if (kw.isNotEmpty && !e.note.toLowerCase().contains(kw)) {
        return false;
      }
      if (start != null && e.timestamp < start.millisecondsSinceEpoch) {
        return false;
      }
      if (end != null && e.timestamp > end.millisecondsSinceEpoch) {
        return false;
      }
      if (_selectedCategoryIds.isNotEmpty &&
          !_selectedCategoryIds.contains(e.categoryId)) {
        return false;
      }
      if (_dayTypeFilter == _DayTypeFilter.workday && e.isRestDay) {
        return false;
      }
      if (_dayTypeFilter == _DayTypeFilter.restDay && !e.isRestDay) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case _ExpenseSort.timeDesc:
          return b.timestamp.compareTo(a.timestamp);
        case _ExpenseSort.timeAsc:
          return a.timestamp.compareTo(b.timestamp);
        case _ExpenseSort.amountDesc:
          return b.amount.compareTo(a.amount);
        case _ExpenseSort.amountAsc:
          return a.amount.compareTo(b.amount);
      }
    });
    return filtered;
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _datePreset = _DateRangePreset.custom;
      });
    }
  }

  Future<void> _batchChangeCategory() async {
    if (_selectedExpenseIds.isEmpty) return;
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
    );
    if (!ok || !mounted) return;

    final cats = ref.read(appControllerProvider).categories;
    final targetCatId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('将已选 ${_selectedExpenseIds.length} 条账单修改为类别'),
        children: cats
            .map(
              (c) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(c.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(c.name, style: const TextStyle(fontSize: 15)),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (targetCatId == null) return;

    await ref
        .read(appControllerProvider.notifier)
        .batchUpdateExpenseCategory(_selectedExpenseIds.toList(), targetCatId);
    setState(() {
      _selectedExpenseIds.clear();
      _batchMode = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('批量修改类别完成')),
      );
    }
  }

  Future<void> _batchDelete() async {
    if (_selectedExpenseIds.isEmpty) return;
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
    );
    if (!ok || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除确认'),
        content: Text('确定删除已选中的 ${_selectedExpenseIds.length} 条支出账单吗？'),
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
            child: const Text('全部删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await ref
        .read(appControllerProvider.notifier)
        .batchDeleteExpenses(_selectedExpenseIds.toList());
    setState(() {
      _selectedExpenseIds.clear();
      _batchMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final themeCfg = state.activeTheme.config;
    final g = themeCfg.globalStyle;
    final hasGlobalBg =
        g.backgroundImagePath != null && g.backgroundImagePath!.isNotEmpty;
    final currency = state.settings.displayCurrency;
    final filtered = _applyFilter(state.expenses);
    final totalAmount = filtered.fold<double>(0.0, (sum, e) => sum + e.amount);

    final hasActiveFilter = _keyword.isNotEmpty ||
        _datePreset != _DateRangePreset.all ||
        _selectedCategoryIds.isNotEmpty ||
        _dayTypeFilter != _DayTypeFilter.all;

    // Pure background appreciation mode
    if (_artPreviewMode && hasGlobalBg) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _artPreviewMode = false),
        child: Stack(
          children: [
            const SizedBox.expand(),
            Positioned(
              right: 16,
              bottom: 20,
              child: FilledButton.tonalIcon(
                onPressed: () => setState(() => _artPreviewMode = false),
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('退出赏图'),
              ),
            ),
          ],
        ),
      );
    }

    // Add a breathable top hero space inside the scrollable list when a global background is present
    final showHeroSpacer = hasGlobalBg && !_showFilters && !_batchMode;

    return Stack(
      children: [
        Column(
          children: [
            // Search & Quick Action Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: GlassSurface(
                      themeConfig: themeCfg,
                      borderRadius: 14,
                      child: TextField(
                        controller: _searchCtrl,
                        style: TextStyle(color: g.textColor, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '搜索备注关键词...',
                          hintStyle: TextStyle(color: g.secondaryTextColor),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: g.secondaryTextColor,
                          ),
                          suffixIcon: _keyword.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _keyword = '');
                                  },
                                )
                              : null,
                          filled: false,
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                        ),
                        onChanged: (v) => setState(() => _keyword = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    tooltip: _minimalistMode ? '切回卡片主题图模式' : '切换极简高透列表模式',
                    onPressed: () =>
                        setState(() => _minimalistMode = !_minimalistMode),
                    icon: Icon(
                      _minimalistMode
                          ? Icons.view_stream_rounded
                          : Icons.view_agenda_outlined,
                      size: 19,
                    ),
                  ),
                  if (hasGlobalBg) ...[
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      tooltip: '纯净赏图模式',
                      onPressed: () => setState(() => _artPreviewMode = true),
                      icon: const Icon(Icons.photo_outlined, size: 19),
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    tooltip: '筛选',
                    onPressed: () =>
                        setState(() => _showFilters = !_showFilters),
                    icon: Icon(
                      hasActiveFilter
                          ? Icons.filter_alt_rounded
                          : Icons.filter_alt_outlined,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),

            // Expandable Multi-dimensional Filter Panel
            if (_showFilters)
              GlassSurface(
                themeConfig: themeCfg,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.all(12),
                borderRadius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in {
                          _DateRangePreset.all: '全部日期',
                          _DateRangePreset.today: '今日',
                          _DateRangePreset.thisWeek: '本周',
                          _DateRangePreset.thisMonth: '本月',
                        }.entries)
                          ChoiceChip(
                            label: Text(entry.value),
                            selected: _datePreset == entry.key,
                            onSelected: (_) =>
                                setState(() => _datePreset = entry.key),
                            visualDensity: VisualDensity.compact,
                          ),
                        ChoiceChip(
                          label: Text(
                            _datePreset == _DateRangePreset.custom &&
                                    _customRange != null
                                ? '${DateUtilsExt.toDateStr(_customRange!.start)} ~ ${DateUtilsExt.toDateStr(_customRange!.end)}'
                                : '自定义日期',
                          ),
                          selected: _datePreset == _DateRangePreset.custom,
                          onSelected: (_) => _pickCustomRange(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: state.categories.map((cat) {
                        final selected = _selectedCategoryIds.contains(cat.id);
                        return FilterChip(
                          label: Text(cat.name),
                          selected: selected,
                          visualDensity: VisualDensity.compact,
                          onSelected: (v) => setState(() {
                            if (v) {
                              _selectedCategoryIds.add(cat.id);
                            } else {
                              _selectedCategoryIds.remove(cat.id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<_DayTypeFilter>(
                            value: _dayTypeFilter,
                            isDense: true,
                            decoration: const InputDecoration(
                              labelText: '日期属性',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: _DayTypeFilter.all,
                                child: Text('全部'),
                              ),
                              DropdownMenuItem(
                                value: _DayTypeFilter.workday,
                                child: Text('仅工作日'),
                              ),
                              DropdownMenuItem(
                                value: _DayTypeFilter.restDay,
                                child: Text('仅休息日'),
                              ),
                            ],
                            onChanged: (v) => setState(
                              () => _dayTypeFilter = v ?? _DayTypeFilter.all,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<_ExpenseSort>(
                            value: _sort,
                            isDense: true,
                            decoration: const InputDecoration(
                              labelText: '排序方式',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: _ExpenseSort.timeDesc,
                                child: Text('时间倒序'),
                              ),
                              DropdownMenuItem(
                                value: _ExpenseSort.timeAsc,
                                child: Text('时间正序'),
                              ),
                              DropdownMenuItem(
                                value: _ExpenseSort.amountDesc,
                                child: Text('金额从高到低'),
                              ),
                              DropdownMenuItem(
                                value: _ExpenseSort.amountAsc,
                                child: Text('金额从低到高'),
                              ),
                            ],
                            onChanged: (v) => setState(
                              () => _sort = v ?? _ExpenseSort.timeDesc,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasActiveFilter)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _keyword = '';
                              _datePreset = _DateRangePreset.all;
                              _customRange = null;
                              _selectedCategoryIds.clear();
                              _dayTypeFilter = _DayTypeFilter.all;
                            });
                          },
                          child: const Text('重置全部筛选'),
                        ),
                      ),
                  ],
                ),
              ),

            // Pinned Real-time Summary Card + Batch Mode Toggle
            GlassSurface(
              themeConfig: themeCfg,
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              borderRadius: 16,
              border: Border.all(color: g.primary.withOpacity(0.22)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasActiveFilter ? '筛选结果总支出' : '累计总支出',
                          style: TextStyle(
                            fontSize: 12,
                            color: g.secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$currency${totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: g.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '共 ${filtered.length} 笔',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: g.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            _batchMode = !_batchMode;
                            _selectedExpenseIds.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _batchMode
                                ? g.primary
                                : g.primary.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _batchMode ? '退出批量' : '批量管理',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _batchMode ? Colors.white : g.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Batch operation bar
            if (_batchMode)
              GlassSurface(
                themeConfig: themeCfg,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                borderRadius: 12,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedExpenseIds.length == filtered.length) {
                            _selectedExpenseIds.clear();
                          } else {
                            _selectedExpenseIds
                              ..clear()
                              ..addAll(filtered.map((e) => e.id));
                          }
                        });
                      },
                      child: Text(
                        _selectedExpenseIds.length == filtered.length &&
                                filtered.isNotEmpty
                            ? '取消全选'
                            : '全选(${filtered.length})',
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '已选 ${_selectedExpenseIds.length}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: g.textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _selectedExpenseIds.isEmpty
                          ? null
                          : _batchChangeCategory,
                      child: const Text('改类别'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed:
                          _selectedExpenseIds.isEmpty ? null : _batchDelete,
                      child: const Text('删除'),
                    ),
                  ],
                ),
              ),

            // Expense list (with breathable background spacer when global background is set)
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: GlassSurface(
                        themeConfig: themeCfg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        borderRadius: 18,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: g.secondaryTextColor.withOpacity(0.7),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              hasActiveFilter
                                  ? '没有符合筛选条件的支出记录'
                                  : '暂无支出记录，点击右下角记一笔吧',
                              style: TextStyle(color: g.secondaryTextColor),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: filtered.length + (showHeroSpacer ? 1 : 0),
                      itemBuilder: (ctx, rawIdx) {
                        if (showHeroSpacer && rawIdx == 0) {
                          return const SizedBox(height: 150);
                        }
                        final idx = showHeroSpacer ? rawIdx - 1 : rawIdx;
                        final exp = filtered[idx];
                        final cat = state.categoryById(exp.categoryId);
                        final selected = _selectedExpenseIds.contains(exp.id);
                        return ExpenseCard(
                          expense: exp,
                          category: cat,
                          themeConfig: themeCfg,
                          currencyPrefix: currency,
                          selectionMode: _batchMode,
                          isSelected: selected,
                          minimalistMode: _minimalistMode,
                          onTap: () {
                            if (_batchMode) {
                              setState(() {
                                if (selected) {
                                  _selectedExpenseIds.remove(exp.id);
                                } else {
                                  _selectedExpenseIds.add(exp.id);
                                }
                              });
                            } else {
                              showExpenseEditorSheet(
                                context,
                                ref,
                                existing: exp,
                              );
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              _batchMode = true;
                              _selectedExpenseIds.add(exp.id);
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
        if (!_batchMode)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'add_expense_fab',
              backgroundColor: g.primary,
              foregroundColor: Colors.white,
              onPressed: () => showExpenseEditorSheet(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                '记一笔',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
