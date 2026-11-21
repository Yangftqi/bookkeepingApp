import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/category.dart';
import '../../models/expense.dart';
import '../../models/theme_config.dart';
import '../../providers/app_providers.dart';
import '../../utils/date_utils_ext.dart';
import '../../utils/math_evaluator.dart';
import '../../widgets/calculator_keyboard.dart';
import '../../widgets/pin_dialog.dart';

Future<void> showExpenseEditorSheet(
  BuildContext context,
  WidgetRef ref, {
  Expense? existing,
}) async {
  final action = existing == null
      ? ProtectedAction.create
      : ProtectedAction.modifyOrDelete;
  final ok = await AuthGuard.requireAction(context, ref, action);
  if (!ok || !context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ExpenseEditorSheet(existing: existing),
  );
}

class _ExpenseEditorSheet extends ConsumerStatefulWidget {
  final Expense? existing;
  const _ExpenseEditorSheet({this.existing});

  @override
  ConsumerState<_ExpenseEditorSheet> createState() =>
      _ExpenseEditorSheetState();
}

class _ExpenseEditorSheetState extends ConsumerState<_ExpenseEditorSheet> {
  static const _uuid = Uuid();

  late String _expression;
  late String _selectedCategoryId;
  late DateTime _selectedDateTime;
  late bool _isRestDay;
  bool _loadingDayType = false;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(appControllerProvider);
    final e = widget.existing;
    if (e != null) {
      _expression = e.amount
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'\.?0+$'), '');
      _selectedCategoryId = e.categoryId;
      _selectedDateTime = e.dateTime;
      _isRestDay = e.isRestDay;
      _noteController = TextEditingController(text: e.note);
    } else {
      _expression = '';
      _selectedCategoryId =
          state.categories.isNotEmpty ? state.categories.first.id : '';
      _selectedDateTime = DateTime.now();
      _isRestDay = DateUtilsExt.isDefaultWeekend(_selectedDateTime);
      _noteController = TextEditingController();
      _loadDayTypeFor(_selectedDateTime);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadDayTypeFor(DateTime dt) async {
    setState(() => _loadingDayType = true);
    final dateStr = DateUtilsExt.toDateStr(dt);
    final isRest =
        await ref.read(appControllerProvider.notifier).resolveIsRestDay(dateStr);
    if (mounted) {
      setState(() {
        _isRestDay = isRest;
        _loadingDayType = false;
      });
    }
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (!mounted) return;

    final newDt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime?.hour ?? _selectedDateTime.hour,
      pickedTime?.minute ?? _selectedDateTime.minute,
    );
    setState(() => _selectedDateTime = newDt);
    await _loadDayTypeFor(newDt);
  }

  Future<void> _save() async {
    final amount = MathEvaluator.evaluate(_expression);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('支出金额必须大于 0')),
      );
      return;
    }

    final state = ref.read(appControllerProvider);
    final user = state.currentUser;
    if (user == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final dateStr = DateUtilsExt.toDateStr(_selectedDateTime);
    final expense = Expense(
      id: widget.existing?.id ?? _uuid.v4(),
      userId: user.id,
      amount: double.parse(amount.toStringAsFixed(2)),
      categoryId: _selectedCategoryId,
      timestamp: _selectedDateTime.millisecondsSinceEpoch,
      dateStr: dateStr,
      isRestDay: _isRestDay,
      note: _noteController.text.trim(),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );

    final syncedOthers =
        await ref.read(appControllerProvider.notifier).saveExpense(expense);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (syncedOthers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已同步更新 $dateStr 当日全部账单为「${_isRestDay ? "休息日" : "工作日"}」',
          ),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账单'),
        content: const Text('确定要删除这条支出记录吗？此操作无法撤销。'),
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
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(appControllerProvider.notifier).deleteExpense(existing.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final themeCfg = state.activeTheme.config;
    final categories = state.categories;
    final currency = state.settings.displayCurrency;
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  widget.existing == null ? '记一笔支出' : '编辑支出账单',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (widget.existing != null)
                  IconButton(
                    tooltip: '删除此条账单',
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Category themed selector grid
            Text(
              '选择类别',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.1,
              ),
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                return _ThemedCategoryChip(
                  category: cat,
                  themeConfig: themeCfg,
                  selected: cat.id == _selectedCategoryId,
                  onTap: () => setState(() => _selectedCategoryId = cat.id),
                );
              },
            ),
            const SizedBox(height: 12),

            // DateTime + Workday/RestDay binding row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDateTime,
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(
                      DateUtilsExt.toDateTimeStr(_selectedDateTime),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(
                        themeCfg.dayTypeStyle.workday.badgeText,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(
                        themeCfg.dayTypeStyle.restDay.badgeText,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  selected: {_isRestDay},
                  onSelectionChanged: _loadingDayType
                      ? null
                      : (set) => setState(() => _isRestDay = set.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Note input
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: '写点备注（如：午饭外卖、超市日用品...）',
                prefixIcon: const Icon(Icons.edit_note_rounded),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Built-in arithmetic calculator keyboard
            CalculatorKeyboard(
              expression: _expression,
              currencyPrefix: currency,
              accentColor: themeCfg.globalStyle.primary,
              onExpressionChanged: (v) => setState(() => _expression = v),
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemedCategoryChip extends StatelessWidget {
  final ExpenseCategory category;
  final ThemeConfig themeConfig;
  final bool selected;
  final VoidCallback onTap;

  const _ThemedCategoryChip({
    required this.category,
    required this.themeConfig,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = themeConfig.styleForCategory(
      categoryId: category.id,
      categoryName: category.name,
      defaultColorHex: category.defaultColorHex,
    );
    final bgPath = style.backgroundImagePath;
    final hasBg = bgPath != null && bgPath.isNotEmpty && File(bgPath).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? style.color : style.color.withOpacity(0.35),
                width: selected ? 2.4 : 1.0,
              ),
              color: hasBg
                  ? null
                  : (selected
                      ? style.color.withOpacity(0.22)
                      : style.color.withOpacity(0.08)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasBg)
                  Image(
                    image: ResizeImage.resizeIfNeeded(
                      320,
                      null,
                      FileImage(File(bgPath)),
                    ),
                    fit: BoxFit.cover,
                  ),
                if (hasBg)
                  ColoredBox(
                    color: Colors.black.withOpacity(selected ? 0.30 : 0.45),
                  ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color: hasBg ? Colors.white : style.color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
