import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/db/app_database.dart';
import '../../models/ai_models.dart';
import '../../models/economic_models.dart';
import '../../providers/app_providers.dart';
import '../../services/llm_service.dart';
import '../../utils/date_utils_ext.dart';
import '../../widgets/pin_dialog.dart';
import 'llm_config_dialog.dart';
import 'role_presets_dialog.dart';

class AiAnalystView extends ConsumerStatefulWidget {
  const AiAnalystView({super.key});

  @override
  ConsumerState<AiAnalystView> createState() => _AiAnalystViewState();
}

class _AiAnalystViewState extends ConsumerState<AiAnalystView> {
  static const _uuid = Uuid();

  late DateTime _startDate;
  late DateTime _endDate;
  bool _includeExpenseDetails = false;
  bool _includeEconomicContext = true;
  String? _selectedRoleId;

  AiChatSession? _activeSession;
  List<AiChatMessage> _messages = [];
  bool _streaming = false;
  String _streamingBuffer = '';
  StreamSubscription<String>? _streamSub;
  String? _lastUserId;

  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateUtilsExt.startOfMonth(now);
    _endDate = DateUtilsExt.endOfDay(now);
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (range != null) {
      setState(() {
        _startDate = DateUtilsExt.startOfDay(range.start);
        _endDate = DateUtilsExt.endOfDay(range.end);
      });
    }
  }

  String _buildBillContextMarkdown({
    required DateTime start,
    required DateTime end,
    EconomicComparisonSnapshot? extraSnapshot,
  }) {
    final state = ref.read(appControllerProvider);
    final currency = state.settings.displayCurrency;
    final startMs = DateUtilsExt.startOfDay(start).millisecondsSinceEpoch;
    final endMs = DateUtilsExt.endOfDay(end).millisecondsSinceEpoch;

    final filtered = state.expenses
        .where((e) => e.timestamp >= startMs && e.timestamp <= endMs)
        .toList();
    final total = filtered.fold<double>(0.0, (sum, e) => sum + e.amount);

    final byCat = <String, double>{};
    final byCatCount = <String, int>{};
    double workTotal = 0.0;
    double restTotal = 0.0;

    for (final e in filtered) {
      final catName = state.categoryById(e.categoryId).name;
      byCat[catName] = (byCat[catName] ?? 0.0) + e.amount;
      byCatCount[catName] = (byCatCount[catName] ?? 0) + 1;
      if (e.isRestDay) {
        restTotal += e.amount;
      } else {
        workTotal += e.amount;
      }
    }

    // Calendar natural-day denominator
    final todayEnd = DateUtilsExt.endOfDay(DateTime.now());
    final effectiveEnd = end.isAfter(todayEnd) ? todayEnd : end;
    final calDays = DateUtilsExt.enumerateDays(start, effectiveEnd);
    int nWork = 0;
    int nRest = 0;
    for (final d in calDays) {
      final dStr = DateUtilsExt.toDateStr(d);
      final isRest =
          state.dayOverrides[dStr] ?? DateUtilsExt.isDefaultWeekend(d);
      if (isRest) {
        nRest++;
      } else {
        nWork++;
      }
    }
    final workAvg = nWork > 0 ? workTotal / nWork : 0.0;
    final restAvg = nRest > 0 ? restTotal / nRest : 0.0;

    final sb = StringBuffer();
    sb.writeln('### 用户支出统计数据快照');
    sb.writeln(
      '- **统计时段**：${DateUtilsExt.toDateStr(start)} 至 ${DateUtilsExt.toDateStr(end)}',
    );
    sb.writeln('- **总支出金额**：$currency${total.toStringAsFixed(2)}（共 ${filtered.length} 笔）');
    sb.writeln('- **各分类支出明细**：');
    final sortedCats = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final c in sortedCats) {
      final pct = total > 0 ? (c.value / total * 100) : 0.0;
      sb.writeln(
        '  - ${c.key}：$currency${c.value.toStringAsFixed(2)}（占比 ${pct.toStringAsFixed(1)}%，${byCatCount[c.key]} 笔）',
      );
    }
    sb.writeln('- **工作日 vs 休息日自然日均对比**：');
    sb.writeln(
      '  - 工作日（$nWork 个自然日）：总计 $currency${workTotal.toStringAsFixed(2)}，自然日均 $currency${workAvg.toStringAsFixed(2)}',
    );
    sb.writeln(
      '  - 休息日（$nRest 个自然日）：总计 $currency${restTotal.toStringAsFixed(2)}，自然日均 $currency${restAvg.toStringAsFixed(2)}',
    );
    if (workAvg > 0) {
      sb.writeln(
        '  - 假日消费倍率：${(restAvg / workAvg).toStringAsFixed(2)}x',
      );
    }

    if (_includeEconomicContext || extraSnapshot != null) {
      sb.writeln('\n### 本地经济学模型对比结果');
      if (extraSnapshot != null) {
        sb.writeln(
          '- **${extraSnapshot.metricName}**：${extraSnapshot.myValuePercent.toStringAsFixed(1)}% '
          '（分子 ${extraSnapshot.selectedCategoryNames.join("、")}：$currency${extraSnapshot.numeratorAmount.toStringAsFixed(2)} / '
          '分母：$currency${extraSnapshot.denominatorAmount.toStringAsFixed(2)}），'
          '评级：${extraSnapshot.matchedTierName ?? "无"}，'
          '样本库前 ${extraSnapshot.percentileFromLow?.toStringAsFixed(1) ?? "N/A"}% 分位（共 ${extraSnapshot.totalSamples} 个样本）。',
        );
      } else if (total > 0) {
        for (final metric in state.economicMetrics) {
          final matchedIds = <String>{};
          for (final cat in state.categories) {
            for (final kw in metric.suggestedCategoryKeywords) {
              if (kw.isNotEmpty &&
                  cat.name.toLowerCase().contains(kw.toLowerCase())) {
                matchedIds.add(cat.id);
                break;
              }
            }
          }
          if (matchedIds.isEmpty) continue;
          final numSum = filtered
              .where((e) => matchedIds.contains(e.categoryId))
              .fold<double>(0.0, (s, e) => s + e.amount);
          final pct = numSum / total * 100.0;
          final benches = state.benchmarksByMetric[metric.id] ?? const [];
          final samples = benches.where((b) => !b.isTierStandard).toList();
          final lower = samples.where((s) => s.value < pct).length;
          final pRank = samples.isNotEmpty ? (lower / samples.length * 100) : null;
          sb.writeln(
            '- **${metric.name}**：${pct.toStringAsFixed(1)}%'
            '${pRank != null ? '（${samples.length}个样本从低到高前 ${pRank.toStringAsFixed(1)}% 分位）' : ''}',
          );
        }
      }
    }

    if (_includeExpenseDetails && filtered.isNotEmpty) {
      sb.writeln('\n### 具体支出条目明细与备注');
      sb.writeln('| 时间 | 类别 | 属性 | 金额 | 备注 |');
      sb.writeln('| :--- | :--- | :--- | ---: | :--- |');
      final cap = filtered.length > 200 ? 200 : filtered.length;
      for (var i = 0; i < cap; i++) {
        final e = filtered[i];
        final catName = state.categoryById(e.categoryId).name;
        final safeNote = e.note.replaceAll('|', '/').replaceAll('\n', ' ');
        sb.writeln(
          '| ${DateUtilsExt.toDateTimeStr(e.dateTime)} | $catName | ${e.isRestDay ? "休息日" : "工作日"} | $currency${e.amount.toStringAsFixed(2)} | $safeNote |',
        );
      }
      if (filtered.length > cap) {
        sb.writeln('\n*（明细超过 $cap 条，已自动截取最新 $cap 条）*');
      }
    }

    return sb.toString();
  }

  Future<void> _sendMessage({
    String? overrideUserPrompt,
    String? sessionTitle,
    DateTime? overrideStart,
    DateTime? overrideEnd,
    EconomicComparisonSnapshot? extraSnapshot,
    bool startNewSession = false,
  }) async {
    final text = (overrideUserPrompt ?? _inputCtrl.text).trim();
    if (text.isEmpty || _streaming) return;

    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.create,
      reason: '发起 AI 账单分析对话需要验证权限',
    );
    if (!ok || !mounted) return;

    final state = ref.read(appControllerProvider);
    final user = state.currentUser;
    if (user == null) return;

    final settings = state.settings;
    if (settings.llmBaseUrl.trim().isEmpty ||
        settings.llmModelName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先点击右上角配置大模型 API 地址与模型名称')),
      );
      await showLlmConfigDialog(context, ref);
      return;
    }

    if (overrideUserPrompt == null) {
      _inputCtrl.clear();
    }

    final presets = settings.aiRolePresets;
    final role = presets.firstWhere(
      (r) => r.id == _selectedRoleId,
      orElse: () => presets.first,
    );

    final effectiveStart = overrideStart ?? _startDate;
    final effectiveEnd = overrideEnd ?? _endDate;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (startNewSession || _activeSession == null) {
      final contextMd = _buildBillContextMarkdown(
        start: effectiveStart,
        end: effectiveEnd,
        extraSnapshot: extraSnapshot,
      );
      final newSession = AiChatSession(
        id: 'ai_sess_${_uuid.v4()}',
        userId: user.id,
        title: sessionTitle ??
            (text.length > 20 ? '${text.substring(0, 20)}...' : text),
        rolePresetId: role.id,
        contextSummaryJson: jsonEncode({
          'start': DateUtilsExt.toDateStr(effectiveStart),
          'end': DateUtilsExt.toDateStr(effectiveEnd),
          'context_md': contextMd,
        }),
        createdAt: now,
      );
      await AppDatabase.instance.upsertAiSession(newSession);
      await ref.read(appControllerProvider.notifier).refreshAiSessions();
      setState(() {
        _activeSession = newSession;
        _messages = [];
      });
    }

    final session = _activeSession!;
    final userMsg = AiChatMessage(
      id: 'ai_msg_${_uuid.v4()}',
      sessionId: session.id,
      role: 'user',
      content: text,
      createdAt: now,
    );
    await AppDatabase.instance.upsertAiMessage(userMsg);
    setState(() {
      _messages = [..._messages, userMsg];
      _streaming = true;
      _streamingBuffer = '';
    });
    _scrollToBottom();

    // Build messages array for OpenAI-compatible API
    String contextMd = '';
    try {
      final decoded = jsonDecode(session.contextSummaryJson) as Map;
      contextMd = decoded['context_md']?.toString() ?? '';
    } catch (_) {}

    final apiMessages = <Map<String, String>>[
      {
        'role': 'system',
        'content': '${role.systemPrompt}\n\n以下是用户的本地账单与统计上下文：\n$contextMd',
      },
      ..._messages.map((m) => {'role': m.role, 'content': m.content}),
    ];

    final stream = LlmService.streamChat(
      baseUrl: settings.llmBaseUrl,
      apiKey: settings.llmApiKey,
      modelName: settings.llmModelName,
      messages: apiMessages,
    );

    _streamSub = stream.listen(
      (chunk) {
        if (!mounted) return;
        setState(() => _streamingBuffer += chunk);
        _scrollToBottom();
      },
      onError: (err) async {
        if (!mounted) return;
        final errContent = _streamingBuffer.isEmpty
            ? '⚠️ 请求大模型失败：$err'
            : '$_streamingBuffer\n\n⚠️ 流式输出中断：$err';
        await _finalizeAssistantMessage(session.id, errContent);
      },
      onDone: () async {
        if (!mounted) return;
        final finalText =
            _streamingBuffer.isEmpty ? '（模型未返回内容）' : _streamingBuffer;
        await _finalizeAssistantMessage(session.id, finalText);
      },
      cancelOnError: true,
    );
  }

  Future<void> _finalizeAssistantMessage(
    String sessionId,
    String content,
  ) async {
    final msg = AiChatMessage(
      id: 'ai_msg_${_uuid.v4()}',
      sessionId: sessionId,
      role: 'assistant',
      content: content,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await AppDatabase.instance.upsertAiMessage(msg);
    if (mounted) {
      setState(() {
        _messages = [..._messages, msg];
        _streaming = false;
        _streamingBuffer = '';
      });
      _scrollToBottom();
    }
  }

  Future<void> _openSessionHistory() async {
    final sessions = ref.read(appControllerProvider).aiSessions;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '本用户历史分析会话 (${sessions.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _activeSession = null;
                        _messages = [];
                      });
                    },
                    icon: const Icon(Icons.add_comment_outlined, size: 18),
                    label: const Text('新建会话'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('暂无历史分析记录')),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = sessions[i];
                      return ListTile(
                        title: Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          DateUtilsExt.toDateTimeStr(
                            DateTime.fromMillisecondsSinceEpoch(s.createdAt),
                          ),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () async {
                            await ref
                                .read(appControllerProvider.notifier)
                                .deleteAiSession(s.id);
                            if (_activeSession?.id == s.id && mounted) {
                              setState(() {
                                _activeSession = null;
                                _messages = [];
                              });
                            }
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                        ),
                        onTap: () async {
                          final msgs = await AppDatabase.instance
                              .getAiMessagesForSession(s.id);
                          if (mounted) {
                            setState(() {
                              _activeSession = s;
                              _messages = msgs;
                              _selectedRoleId = s.rolePresetId;
                            });
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final g = state.activeTheme.config.globalStyle;
    final presets = state.settings.aiRolePresets;
    if (_selectedRoleId == null && presets.isNotEmpty) {
      _selectedRoleId = presets.first.id;
    }

    // Reset active chat view when switching user accounts
    if (_lastUserId != state.currentUserId) {
      _lastUserId = state.currentUserId;
      _activeSession = null;
      _messages = [];
    }

    // Consume one-click analysis request from Economics tab
    final pending = state.pendingAiRequest;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(appControllerProvider.notifier).clearPendingAiRequest();
        setState(() {
          _startDate = pending.startDate;
          _endDate = pending.endDate;
          _includeEconomicContext = true;
        });
        _sendMessage(
          overrideUserPrompt: pending.contextPrompt,
          sessionTitle: pending.title,
          overrideStart: pending.startDate,
          overrideEnd: pending.endDate,
          extraSnapshot: pending.economicSnapshot,
          startNewSession: true,
        );
      });
    }

    return Column(
      children: [
        // Top Context Composer & Config Bar
        Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: g.surface.withOpacity(0.94),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: presets.any((p) => p.id == _selectedRoleId)
                          ? _selectedRoleId
                          : (presets.isNotEmpty ? presets.first.id : null),
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'AI 分析角色',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: presets
                          .map(
                            (r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(
                                '${r.name} · ${r.displayTagline}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedRoleId = v),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: '角色预设管理',
                    onPressed: () => showRolePresetsDialog(context, ref),
                    icon: const Icon(Icons.masks_outlined),
                  ),
                  IconButton(
                    tooltip: 'API 配置',
                    onPressed: () => showLlmConfigDialog(context, ref),
                    icon: const Icon(Icons.key_rounded),
                  ),
                  IconButton(
                    tooltip: '历史会话',
                    onPressed: _openSessionHistory,
                    icon: const Icon(Icons.history_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.date_range_rounded, size: 15),
                    label: Text(
                      '${DateUtilsExt.toDateStr(_startDate)} ~ ${DateUtilsExt.toDateStr(_endDate)}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: _pickDateRange,
                  ),
                  FilterChip(
                    label: const Text('附带条目明细', style: TextStyle(fontSize: 11.5)),
                    selected: _includeExpenseDetails,
                    visualDensity: VisualDensity.compact,
                    onSelected: (v) =>
                        setState(() => _includeExpenseDetails = v),
                  ),
                  FilterChip(
                    label: const Text('附带经济学模型', style: TextStyle(fontSize: 11.5)),
                    selected: _includeEconomicContext,
                    visualDensity: VisualDensity.compact,
                    onSelected: (v) =>
                        setState(() => _includeEconomicContext = v),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Chat Message List
        Expanded(
          child: _messages.isEmpty && !_streaming
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: g.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 44,
                            color: g.primary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'AI 账单分析师就绪',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: g.textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '选择分析时段与角色，一键开启流式多轮财务诊断。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: g.secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final quickPrompt in [
                                '帮我全面分析这段时间的消费结构和恩格尔系数',
                                '看看我休息日和工作日的消费差距有多大，给3条省钱建议',
                                '帮我找出近期隐藏的“拿铁因子”高频低效消费',
                              ])
                                ActionChip(
                                  label: Text(
                                    quickPrompt,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => _sendMessage(
                                    overrideUserPrompt: quickPrompt,
                                    startNewSession: true,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: _messages.length + (_streaming ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == _messages.length) {
                      return _ChatBubble(
                        isUser: false,
                        content: _streamingBuffer.isEmpty
                            ? '正在思考分析中...'
                            : '$_streamingBuffer ▍',
                        primaryColor: g.primary,
                        surfaceColor: g.surface.withOpacity(0.95),
                        textColor: g.textColor,
                      );
                    }
                    final msg = _messages[i];
                    return _ChatBubble(
                      isUser: msg.role == 'user',
                      content: msg.content,
                      primaryColor: g.primary,
                      surfaceColor: g.surface.withOpacity(0.95),
                      textColor: g.textColor,
                    );
                  },
                ),
        ),

        // Bottom Composer Input
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: g.surface.withOpacity(0.96),
            border: Border(
              top: BorderSide(color: g.secondaryTextColor.withOpacity(0.15)),
            ),
          ),
          child: Row(
            children: [
              if (_activeSession != null)
                IconButton(
                  tooltip: '开启全新会话',
                  onPressed: _streaming
                      ? null
                      : () => setState(() {
                            _activeSession = null;
                            _messages = [];
                          }),
                  icon: const Icon(Icons.add_comment_outlined),
                ),
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: _activeSession == null
                        ? '输入问题，开始分析所选时段账单...'
                        : '继续追问...',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              if (_streaming)
                IconButton.filled(
                  onPressed: () async {
                    await _streamSub?.cancel();
                    if (_activeSession != null) {
                      await _finalizeAssistantMessage(
                        _activeSession!.id,
                        _streamingBuffer.isEmpty
                            ? '（已手动停止生成）'
                            : '$_streamingBuffer\n\n*（已手动停止生成）*',
                      );
                    }
                  },
                  icon: const Icon(Icons.stop_rounded),
                )
              else
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: g.primary),
                  onPressed: () => _sendMessage(),
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isUser;
  final String content;
  final Color primaryColor;
  final Color surfaceColor;
  final Color textColor;

  const _ChatBubble({
    required this.isUser,
    required this.content,
    required this.primaryColor,
    required this.surfaceColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        decoration: BoxDecoration(
          color: isUser ? primaryColor : surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: isUser
            ? Text(
                content,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              )
            : MarkdownBody(
                data: content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(color: textColor, fontSize: 13.8, height: 1.48),
                  h1: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                  h2: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                  h3: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                  listBullet: TextStyle(color: textColor),
                  strong: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );
  }
}
