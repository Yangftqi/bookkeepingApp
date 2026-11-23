import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../models/expense.dart';
import '../../models/theme_config.dart';
import '../../providers/app_providers.dart';
import '../../utils/date_utils_ext.dart';
import '../../widgets/glass_surface.dart';

enum StatsPeriod { day, week, month }

class _CatStat {
  final ExpenseCategory category;
  final Color color;
  final double amount;
  final int count;

  const _CatStat({
    required this.category,
    required this.color,
    required this.amount,
    required this.count,
  });
}

class StatsTab extends ConsumerStatefulWidget {
  const StatsTab({super.key});

  @override
  ConsumerState<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends ConsumerState<StatsTab> {
  StatsPeriod _period = StatsPeriod.month;
  DateTime _anchor = DateTime.now();
  int _touchedPieIndex = -1;
  bool _monthAsLineChart = true;
  int? _selectedTrendIndex;

  void _shiftPeriod(int delta) {
    setState(() {
      _touchedPieIndex = -1;
      _selectedTrendIndex = null;
      switch (_period) {
        case StatsPeriod.day:
          _anchor = _anchor.add(Duration(days: delta));
          break;
        case StatsPeriod.week:
          _anchor = _anchor.add(Duration(days: 7 * delta));
          break;
        case StatsPeriod.month:
          _anchor = DateTime(_anchor.year, _anchor.month + delta, 1);
          break;
      }
    });
  }

  (DateTime, DateTime, String) _periodBounds() {
    switch (_period) {
      case StatsPeriod.day:
        final s = DateUtilsExt.startOfDay(_anchor);
        final e = DateUtilsExt.endOfDay(_anchor);
        return (s, e, DateUtilsExt.toDateStr(_anchor));
      case StatsPeriod.week:
        final s = DateUtilsExt.startOfWeek(_anchor);
        final e = DateUtilsExt.endOfWeek(_anchor);
        return (
          s,
          e,
          '${DateUtilsExt.toDateStr(s).substring(5)} ~ ${DateUtilsExt.toDateStr(e).substring(5)}'
        );
      case StatsPeriod.month:
        final s = DateUtilsExt.startOfMonth(_anchor);
        final e = DateUtilsExt.endOfMonth(_anchor);
        return (s, e, DateUtilsExt.toMonthTitle(_anchor));
    }
  }

  (List<double>, List<String>, List<String>) _computeTrendSeries(
    List<Expense> periodExpenses,
    DateTime start,
    DateTime end,
  ) {
    if (_period == StatsPeriod.day) {
      final values = List<double>.filled(24, 0.0);
      final labels = List<String>.generate(24, (h) => '$h');
      final fullLabels = List<String>.generate(
        24,
        (h) => '${h.toString().padLeft(2, '0')}:00 - ${h.toString().padLeft(2, '0')}:59',
      );
      for (final e in periodExpenses) {
        values[e.dateTime.hour] += e.amount;
      }
      return (values, labels, fullLabels);
    } else if (_period == StatsPeriod.week) {
      final values = List<double>.filled(7, 0.0);
      const labels = ['一', '二', '三', '四', '五', '六', '日'];
      final fullLabels = List<String>.generate(7, (i) {
        final d = start.add(Duration(days: i));
        return '周${labels[i]} (${d.month}/${d.day})';
      });
      for (final e in periodExpenses) {
        values[e.dateTime.weekday - 1] += e.amount;
      }
      return (values, labels, fullLabels);
    } else {
      final daysInMonth = end.day;
      final values = List<double>.filled(daysInMonth, 0.0);
      final labels = List<String>.generate(daysInMonth, (i) => '${i + 1}');
      final fullLabels = List<String>.generate(
        daysInMonth,
        (i) => '${_anchor.month}月${i + 1}日',
      );
      for (final e in periodExpenses) {
        final idx = (e.dateTime.day - 1).clamp(0, daysInMonth - 1);
        values[idx] += e.amount;
      }
      return (values, labels, fullLabels);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final themeCfg = state.activeTheme.config;
    final g = themeCfg.globalStyle;
    final currency = state.settings.displayCurrency;
    final (start, end, periodLabel) = _periodBounds();

    final periodExpenses = state.expenses.where((e) {
      return e.timestamp >= start.millisecondsSinceEpoch &&
          e.timestamp <= end.millisecondsSinceEpoch;
    }).toList();

    final totalAmount =
        periodExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    // 1. Category breakdown
    final byCatAmount = <String, double>{};
    final byCatCount = <String, int>{};
    for (final e in periodExpenses) {
      byCatAmount[e.categoryId] = (byCatAmount[e.categoryId] ?? 0.0) + e.amount;
      byCatCount[e.categoryId] = (byCatCount[e.categoryId] ?? 0) + 1;
    }
    final catStats = byCatAmount.entries.map((entry) {
      final cat = state.categoryById(entry.key);
      final style = themeCfg.styleForCategory(
        categoryId: cat.id,
        categoryName: cat.name,
        defaultColorHex: cat.defaultColorHex,
      );
      return _CatStat(
        category: cat,
        color: style.color,
        amount: entry.value,
        count: byCatCount[entry.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    if (_touchedPieIndex >= catStats.length) {
      _touchedPieIndex = -1;
    }

    // 2. Trend series
    final (trendValues, trendLabels, trendFullLabels) =
        _computeTrendSeries(periodExpenses, start, end);
    if (_selectedTrendIndex != null &&
        _selectedTrendIndex! >= trendValues.length) {
      _selectedTrendIndex = null;
    }

    // 3. Workday vs Rest-day strictly using natural calendar day denominator
    final todayEnd = DateUtilsExt.endOfDay(DateTime.now());
    final effectiveEnd = end.isAfter(todayEnd) ? todayEnd : end;
    final calendarDays = DateUtilsExt.enumerateDays(start, effectiveEnd);
    int nWork = 0;
    int nRest = 0;
    for (final d in calendarDays) {
      final dStr = DateUtilsExt.toDateStr(d);
      final isRest =
          state.dayOverrides[dStr] ?? DateUtilsExt.isDefaultWeekend(d);
      if (isRest) {
        nRest++;
      } else {
        nWork++;
      }
    }
    double workTotal = 0.0;
    double restTotal = 0.0;
    for (final e in periodExpenses) {
      if (e.isRestDay) {
        restTotal += e.amount;
      } else {
        workTotal += e.amount;
      }
    }
    final workAvg = nWork > 0 ? workTotal / nWork : 0.0;
    final restAvg = nRest > 0 ? restTotal / nRest : 0.0;
    final holidayRatio = workAvg > 0 ? (restAvg / workAvg) : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
      children: [
        // Period switcher + Navigator
        GlassSurface(
          themeConfig: themeCfg,
          padding: const EdgeInsets.all(12),
          borderRadius: 16,
          child: Column(
            children: [
              SegmentedButton<StatsPeriod>(
                segments: const [
                  ButtonSegment(value: StatsPeriod.day, label: Text('日')),
                  ButtonSegment(value: StatsPeriod.week, label: Text('周')),
                  ButtonSegment(value: StatsPeriod.month, label: Text('月')),
                ],
                selected: {_period},
                onSelectionChanged: (s) => setState(() {
                  _period = s.first;
                  _touchedPieIndex = -1;
                  _selectedTrendIndex = null;
                }),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: '上一周期',
                    onPressed: () => _shiftPeriod(-1),
                    icon: Icon(Icons.chevron_left_rounded, color: g.textColor),
                  ),
                  Column(
                    children: [
                      Text(
                        periodLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: g.textColor,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 22),
                        ),
                        onPressed: () => setState(() {
                          _anchor = DateTime.now();
                          _touchedPieIndex = -1;
                          _selectedTrendIndex = null;
                        }),
                        child: const Text('回到今日', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: '下一周期',
                    onPressed: () => _shiftPeriod(1),
                    icon: Icon(Icons.chevron_right_rounded, color: g.textColor),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // CARD 1: Total Expense + Interactive PieChart + Category Ranking
        _StatsCard(
          themeConfig: themeCfg,
          title: '总支出与分类占比',
          textColor: g.textColor,
          trailing: Text(
            '$currency${totalAmount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: g.primary,
            ),
          ),
          child: catStats.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      '该周期暂无支出数据',
                      style: TextStyle(color: g.secondaryTextColor),
                    ),
                  ),
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              centerSpaceRadius: 58,
                              sectionsSpace: 2,
                              pieTouchData: PieTouchData(
                                enabled: true,
                                touchCallback: (event, response) {
                                  if (event is! FlTapUpEvent) return;
                                  final idx = response
                                      ?.touchedSection?.touchedSectionIndex;
                                  if (idx == null ||
                                      idx < 0 ||
                                      idx >= catStats.length) {
                                    setState(() => _touchedPieIndex = -1);
                                    return;
                                  }
                                  setState(() {
                                    _touchedPieIndex =
                                        (_touchedPieIndex == idx) ? -1 : idx;
                                  });
                                },
                              ),
                              sections: List.generate(catStats.length, (i) {
                                final item = catStats[i];
                                final isTouched = i == _touchedPieIndex;
                                final pct = totalAmount > 0
                                    ? (item.amount / totalAmount * 100)
                                    : 0.0;
                                return PieChartSectionData(
                                  color: item.color,
                                  value: item.amount,
                                  radius: isTouched ? 58 : 46,
                                  title: pct >= 7
                                      ? '${pct.toStringAsFixed(1)}%'
                                      : '',
                                  titleStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 108,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_touchedPieIndex >= 0 &&
                                    _touchedPieIndex < catStats.length) ...[
                                  Text(
                                    catStats[_touchedPieIndex].category.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: catStats[_touchedPieIndex].color,
                                    ),
                                  ),
                                  Text(
                                    '$currency${catStats[_touchedPieIndex].amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: g.textColor,
                                    ),
                                  ),
                                  Text(
                                    '${(catStats[_touchedPieIndex].amount / totalAmount * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: g.secondaryTextColor,
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    '共 ${periodExpenses.length} 笔',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: g.secondaryTextColor,
                                    ),
                                  ),
                                  Text(
                                    '轻点扇区/列表',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: g.secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(catStats.length, (i) {
                      final item = catStats[i];
                      final ratio =
                          totalAmount > 0 ? item.amount / totalAmount : 0.0;
                      final highlighted = i == _touchedPieIndex;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() {
                          _touchedPieIndex = _touchedPieIndex == i ? -1 : i;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: highlighted
                                ? item.color.withOpacity(0.16)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: item.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${item.category.name} (${item.count}笔)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: g.textColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$currency${item.amount.toStringAsFixed(2)}  ${(ratio * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: g.textColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 6,
                                  color: item.color,
                                  backgroundColor:
                                      item.color.withOpacity(0.15),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
        ),
        const SizedBox(height: 12),

        // CARD 2: Time Trend Chart with Tap-to-Pin Persistent Value Pill
        _StatsCard(
          themeConfig: themeCfg,
          title: _period == StatsPeriod.day
              ? '当日 24 小时支出分布'
              : _period == StatsPeriod.week
                  ? '本周每日支出趋势'
                  : '本月每日支出趋势',
          textColor: g.textColor,
          trailing: _period == StatsPeriod.month
              ? TextButton(
                  onPressed: () => setState(() {
                    _monthAsLineChart = !_monthAsLineChart;
                    _selectedTrendIndex = null;
                  }),
                  child: Text(_monthAsLineChart ? '切为柱状图' : '切为折线图'),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Persistent pinned value capsule above chart (tap bar/point to pin!)
              if (_selectedTrendIndex != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.65),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${trendFullLabels[_selectedTrendIndex!]}：$currency${trendValues[_selectedTrendIndex!].toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: g.textColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _selectedTrendIndex = null),
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: g.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '轻点柱子或折线节点即可锁定查看具体金额',
                    style: TextStyle(
                      fontSize: 11,
                      color: g.secondaryTextColor,
                    ),
                  ),
                ),
              SizedBox(
                height: 200,
                child: _buildTrendChart(
                  values: trendValues,
                  labels: trendLabels,
                  primaryColor: g.primary,
                  textColor: g.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // CARD 3: Workday vs Rest-day Comparison
        _StatsCard(
          themeConfig: themeCfg,
          title: '工作日 vs 休息日',
          textColor: g.textColor,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '工作日 $nWork天 · 休息日 $nRest天',
                style: TextStyle(fontSize: 11.5, color: g.secondaryTextColor),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '查看统计口径',
                icon: Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: g.secondaryTextColor,
                ),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('日均支出统计口径'),
                      content: const Text(
                        '严格按该周期内已过去的全部自然日天数作为分母（未产生消费的自然日计 0 元并计入天数分母），同日属性优先读取手动绑定记录。',
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
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (totalAmount > 0
                                ? (workTotal / totalAmount * 1000).round()
                                : 500)
                            .clamp(1, 999),
                        child: ColoredBox(
                          color: themeCfg.dayTypeStyle.workday.badgeColorObj,
                        ),
                      ),
                      Expanded(
                        flex: (totalAmount > 0
                                ? (restTotal / totalAmount * 1000).round()
                                : 500)
                            .clamp(1, 999),
                        child: ColoredBox(
                          color: themeCfg.dayTypeStyle.restDay.badgeColorObj,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DayCompareBox(
                      label: themeCfg.dayTypeStyle.workday.badgeText,
                      color: themeCfg.dayTypeStyle.workday.badgeColorObj,
                      totalText: '$currency${workTotal.toStringAsFixed(2)}',
                      pctText: totalAmount > 0
                          ? '${(workTotal / totalAmount * 100).toStringAsFixed(1)}%'
                          : '0.0%',
                      dailyAvgText: '日均 $currency${workAvg.toStringAsFixed(2)}',
                      textColor: g.textColor,
                      subTextColor: g.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DayCompareBox(
                      label: themeCfg.dayTypeStyle.restDay.badgeText,
                      color: themeCfg.dayTypeStyle.restDay.badgeColorObj,
                      totalText: '$currency${restTotal.toStringAsFixed(2)}',
                      pctText: totalAmount > 0
                          ? '${(restTotal / totalAmount * 100).toStringAsFixed(1)}%'
                          : '0.0%',
                      dailyAvgText: '日均 $currency${restAvg.toStringAsFixed(2)}',
                      textColor: g.textColor,
                      subTextColor: g.secondaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: g.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  holidayRatio != null
                      ? '假日消费倍率：${holidayRatio.toStringAsFixed(2)}x'
                      : '假日消费倍率：暂无基准',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: g.textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChart({
    required List<double> values,
    required List<String> labels,
    required Color primaryColor,
    required Color textColor,
  }) {
    final maxVal = values.fold<double>(0.0, (m, v) => v > m ? v : m);
    final maxY = maxVal <= 0 ? 10.0 : (maxVal * 1.2);
    const highlightColor = Color(0xFFF59E0B);

    if (_period == StatsPeriod.month && _monthAsLineChart) {
      return LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: false,
            touchCallback: (event, response) {
              if (event is! FlTapUpEvent) return;
              final spots = response?.lineBarSpots;
              if (spots == null || spots.isEmpty) return;
              final idx = spots.first.x.toInt();
              if (idx < 0 || idx >= values.length) return;
              setState(() {
                _selectedTrendIndex = (_selectedTrendIndex == idx) ? null : idx;
              });
            },
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: textColor.withOpacity(0.15),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style: TextStyle(fontSize: 10, color: textColor),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  return Text(
                    '${labels[i]}日',
                    style: TextStyle(fontSize: 10, color: textColor),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                values.length,
                (i) => FlSpot(i.toDouble(), values[i]),
              ),
              isCurved: true,
              preventCurveOverShooting: true,
              color: primaryColor,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, _) =>
                    _selectedTrendIndex != null &&
                    spot.x.toInt() == _selectedTrendIndex,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 5.5,
                  color: highlightColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: primaryColor.withOpacity(0.16),
              ),
            ),
          ],
        ),
      );
    }

    final step = _period == StatsPeriod.day
        ? 4
        : (_period == StatsPeriod.month ? 5 : 1);

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: false,
          touchCallback: (event, response) {
            if (event is! FlTapUpEvent) return;
            final idx = response?.spot?.touchedBarGroupIndex;
            if (idx == null || idx < 0 || idx >= values.length) return;
            setState(() {
              _selectedTrendIndex = (_selectedTrendIndex == idx) ? null : idx;
            });
          },
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: textColor.withOpacity(0.15),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: TextStyle(fontSize: 10, color: textColor),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length || i % step != 0) {
                  return const SizedBox();
                }
                return Text(
                  labels[i],
                  style: TextStyle(fontSize: 10, color: textColor),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(
          values.length,
          (i) {
            final isPinned = _selectedTrendIndex == i;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: isPinned ? highlightColor : primaryColor,
                  width: _period == StatsPeriod.week
                      ? (isPinned ? 22 : 18)
                      : (isPinned ? 8 : 6),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final ThemeConfig themeConfig;
  final String title;
  final Color textColor;
  final Widget? trailing;
  final Widget child;

  const _StatsCard({
    required this.themeConfig,
    required this.title,
    required this.textColor,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      themeConfig: themeConfig,
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DayCompareBox extends StatelessWidget {
  final String label;
  final Color color;
  final String totalText;
  final String pctText;
  final String dailyAvgText;
  final Color textColor;
  final Color subTextColor;

  const _DayCompareBox({
    required this.label,
    required this.color,
    required this.totalText,
    required this.pctText,
    required this.dailyAvgText,
    required this.textColor,
    required this.subTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                pctText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            totalText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dailyAvgText,
            style: TextStyle(fontSize: 11, color: subTextColor),
          ),
        ],
      ),
    );
  }
}
