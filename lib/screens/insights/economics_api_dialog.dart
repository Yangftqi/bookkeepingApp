import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/seed_data.dart';
import '../../providers/app_providers.dart';
import '../../services/llm_service.dart';
import '../../services/world_bank_service.dart';

Future<String?> showEconomicsApiDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  return showDialog<String>(
    context: context,
    builder: (ctx) => const _EconomicsApiDialog(),
  );
}

class _EconomicsApiDialog extends ConsumerStatefulWidget {
  const _EconomicsApiDialog();

  @override
  ConsumerState<_EconomicsApiDialog> createState() =>
      _EconomicsApiDialogState();
}

class _EconomicsApiDialogState extends ConsumerState<_EconomicsApiDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Engine 1: LLM
  final TextEditingController _topicCtrl = TextEditingController();

  // Engine 2: World Bank / Custom JSON
  bool _useCustomUrl = false;
  final TextEditingController _wbCodeCtrl =
      TextEditingController(text: 'NE.CON.PRVT.ZS');
  final TextEditingController _wbNameCtrl =
      TextEditingController(text: '居民最终消费占 GDP 比例 (世界银行)');
  final TextEditingController _customUrlCtrl = TextEditingController();
  final TextEditingController _keywordsCtrl =
      TextEditingController(text: '吃,用,玩');

  bool _loading = false;
  String? _error;
  GeneratedEconomicModel? _preview;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _topicCtrl.dispose();
    _wbCodeCtrl.dispose();
    _wbNameCtrl.dispose();
    _customUrlCtrl.dispose();
    _keywordsCtrl.dispose();
    super.dispose();
  }

  Future<void> _runLlmEngine() async {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) {
      setState(() => _error = '请输入想对比的经济学或消费统计主题');
      return;
    }
    final settings = ref.read(appControllerProvider).settings;
    final activeProfile = settings.activeLlmProfile;
    if (activeProfile.baseUrl.trim().isEmpty ||
        activeProfile.modelName.trim().isEmpty) {
      setState(() => _error = '请先在 AI 账单分析师或设置中配置大模型 API 地址与模型名');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });
    try {
      final result = await LlmService.generateEconomicModel(
        profile: activeProfile,
        topic: topic,
      );
      if (mounted) {
        setState(() {
          _preview = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'AI 生成模型失败：$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _runPublicApiEngine() async {
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });
    try {
      final keywords = _keywordsCtrl.text
          .split(RegExp(r'[,，、\s]+'))
          .where((e) => e.trim().isNotEmpty)
          .toList();
      final result = _useCustomUrl
          ? await WorldBankService.fetchCustomJsonUrl(
              url: _customUrlCtrl.text,
              fallbackName: _wbNameCtrl.text,
              keywords: keywords,
            )
          : await WorldBankService.fetchWorldBankIndicator(
              indicatorCode: _wbCodeCtrl.text,
              customName: _wbNameCtrl.text,
              keywords: keywords,
            );
      if (mounted) {
        setState(() {
          _preview = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '公开 API 拉取失败：$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _savePreview() async {
    final model = _preview;
    if (model == null) return;
    await ref
        .read(appControllerProvider.notifier)
        .saveEconomicModel(model.metric, model.benchmarks);
    if (mounted) {
      Navigator.of(context).pop(model.metric.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('⚡ API 一键拉取/生成经济学模型'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(text: '引擎1: AI结构化生成'),
                  Tab(text: '引擎2: 世行/JSON API'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 250,
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // Engine 1: LLM
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '输入任意经济学或消费统计主题，大模型将按严格 JSON Schema 生成指标定义、评级区间与 20~30 个代表性国家/群体基准：',
                            style: TextStyle(fontSize: 12.5),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _topicCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: '统计模型主题',
                              hintText:
                                  '例如：世界各国文化娱乐支出占总消费比例 / 中国一二三线城市青年餐饮消费系数',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final example in [
                                '世界各国文化娱乐支出占总消费比例',
                                '全球主要国家交通与通讯支出占比',
                                '中国一二三线城市青年餐饮与日用消费系数',
                              ])
                                ActionChip(
                                  label: Text(
                                    example,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      setState(() => _topicCtrl.text = example),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _loading ? null : _runLlmEngine,
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: const Text('调用 AI 生成模型'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Engine 2: World Bank / Custom REST JSON
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('使用自定义 REST JSON URL'),
                            subtitle: Text(
                              _useCustomUrl
                                  ? '输入返回标准 JSON 或 name/value 数组的接口 URL'
                                  : '直连 World Bank Open API v2 拉取各国最新年份指标',
                              style: const TextStyle(fontSize: 11),
                            ),
                            value: _useCustomUrl,
                            onChanged: (v) => setState(() => _useCustomUrl = v),
                          ),
                          if (!_useCustomUrl) ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: SeedData.worldBankPresets.map((p) {
                                return ActionChip(
                                  label: Text(
                                    p['code'] as String,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    setState(() {
                                      _wbCodeCtrl.text = p['code'] as String;
                                      _wbNameCtrl.text = p['name'] as String;
                                      _keywordsCtrl.text =
                                          (p['keywords'] as List).join(',');
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _wbCodeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'World Bank 指标代码',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ] else ...[
                            TextField(
                              controller: _customUrlCtrl,
                              decoration: const InputDecoration(
                                labelText: '自定义 REST JSON URL',
                                hintText: 'https://example.com/metrics.json',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextField(
                            controller: _wbNameCtrl,
                            decoration: const InputDecoration(
                              labelText: '保存的模型名称',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _keywordsCtrl,
                            decoration: const InputDecoration(
                              labelText: '推荐分子类别关键词（逗号分隔）',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _loading ? null : _runPublicApiEngine,
                              icon: const Icon(Icons.cloud_download_rounded),
                              label: const Text('立即拉取并清洗建模'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
                const SizedBox(height: 6),
                const Text('正在请求外部 API 并解析统计基准数据...', style: TextStyle(fontSize: 12)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: cs.error, fontSize: 12),
                ),
              ],
              if (_preview != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✅ 生成成功：${_preview!.metric.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '包含 ${_preview!.benchmarks.where((b) => b.isTierStandard).length} 个评级区间、'
                        '${_preview!.benchmarks.where((b) => !b.isTierStandard).length} 个对比样本。',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('关闭'),
        ),
        if (_preview != null)
          FilledButton.icon(
            onPressed: _savePreview,
            icon: const Icon(Icons.save_rounded),
            label: const Text('一键入库保存'),
          ),
      ],
    );
  }
}
