import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/ai_models.dart';
import '../../services/llm_service.dart';

Future<LlmProfile?> showLlmProfileEditorDialog(
  BuildContext context, {
  LlmProfile? existing,
}) async {
  return showDialog<LlmProfile>(
    context: context,
    builder: (ctx) => _LlmProfileEditorDialog(existing: existing),
  );
}

class _LlmProfileEditorDialog extends ConsumerStatefulWidget {
  final LlmProfile? existing;
  const _LlmProfileEditorDialog({this.existing});

  @override
  ConsumerState<_LlmProfileEditorDialog> createState() =>
      _LlmProfileEditorDialogState();
}

class _LlmProfileEditorDialogState
    extends ConsumerState<_LlmProfileEditorDialog> {
  static const _uuid = Uuid();

  late TextEditingController _nameCtrl;
  late LlmApiFormat _format;
  late TextEditingController _baseUrlCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _modelCtrl;

  bool _obscureKey = true;
  bool _fetchingModels = false;
  bool _testing = false;
  String? _statusText;
  bool _statusSuccess = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _format = p?.apiFormat ?? LlmApiFormat.openaiCompatible;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _baseUrlCtrl = TextEditingController(
      text: p?.baseUrl ?? _format.defaultBaseUrl,
    );
    _apiKeyCtrl = TextEditingController(text: p?.apiKey ?? '');
    _modelCtrl = TextEditingController(
      text: p?.modelName ?? _format.defaultModel,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _onFormatChanged(LlmApiFormat next) {
    final oldFormat = _format;
    setState(() {
      _format = next;
      // Auto-update default URL/model if user hasn't customized away from the previous format's default
      if (_baseUrlCtrl.text.trim().isEmpty ||
          _baseUrlCtrl.text.trim() == oldFormat.defaultBaseUrl) {
        _baseUrlCtrl.text = next.defaultBaseUrl;
      }
      if (_modelCtrl.text.trim().isEmpty ||
          _modelCtrl.text.trim() == oldFormat.defaultModel) {
        _modelCtrl.text = next.defaultModel;
      }
    });
  }

  Future<void> _fetchAndPickModel() async {
    setState(() {
      _fetchingModels = true;
      _statusText = null;
    });
    try {
      final models = await LlmService.fetchModels(
        apiFormat: _format,
        baseUrl: _baseUrlCtrl.text,
        apiKey: _apiKeyCtrl.text,
      );
      if (!mounted) return;
      setState(() => _fetchingModels = false);

      final picked = await showDialog<String>(
        context: context,
        builder: (ctx) => _SearchableModelPickerDialog(
          models: models,
          currentModel: _modelCtrl.text.trim(),
        ),
      );
      if (picked != null && mounted) {
        setState(() {
          _modelCtrl.text = picked;
          _statusSuccess = true;
          _statusText = '已选择模型：$picked（共获取到 ${models.length} 个可用模型）';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchingModels = false;
          _statusSuccess = false;
          _statusText = '拉取模型列表失败：$e';
        });
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _statusText = null;
    });
    try {
      final reply = await LlmService.testConnection(
        apiFormat: _format,
        baseUrl: _baseUrlCtrl.text,
        apiKey: _apiKeyCtrl.text,
        modelName: _modelCtrl.text,
      );
      if (mounted) {
        setState(() {
          _testing = false;
          _statusSuccess = true;
          _statusText = '连接成功！回复：$reply';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _statusSuccess = false;
          _statusText = '连接失败：$e';
        });
      }
    }
  }

  void _save() {
    final baseUrl = _baseUrlCtrl.text.trim();
    final modelName = _modelCtrl.text.trim();
    if (baseUrl.isEmpty || modelName.isEmpty) {
      setState(() {
        _statusSuccess = false;
        _statusText = 'Base URL 和模型名称不能为空';
      });
      return;
    }
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : '${_format.shortBadge} ($modelName)';
    final profile = LlmProfile(
      id: widget.existing?.id ?? 'llm_${_uuid.v4().substring(0, 8)}',
      name: name,
      apiFormat: _format,
      baseUrl: baseUrl,
      apiKey: _apiKeyCtrl.text.trim(),
      modelName: modelName,
    );
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final quickUrls = _format.quickBaseUrls;

    return AlertDialog(
      title: Text(widget.existing == null ? '新建 API 配置' : '编辑 API 配置'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '配置名称',
                  hintText: '如：DeepSeek 主力、Gemini 2.5、Claude 备用',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<LlmApiFormat>(
                value: _format,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'API 协议格式',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: LlmApiFormat.values
                    .map(
                      (fmt) => DropdownMenuItem(
                        value: fmt,
                        child: Text(fmt.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) _onFormatChanged(v);
                },
              ),
              const SizedBox(height: 5),
              Text(
                _format.providersHint,
                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _baseUrlCtrl,
                decoration: InputDecoration(
                  labelText: 'Base URL',
                  hintText: _format.defaultBaseUrl,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: PopupMenuButton<String>(
                    tooltip: '常用官方地址快捷填入',
                    icon: const Icon(Icons.arrow_drop_down_circle_outlined),
                    onSelected: (url) => setState(() => _baseUrlCtrl.text = url),
                    itemBuilder: (_) => quickUrls
                        .map(
                          (item) => PopupMenuItem<String>(
                            value: item['url']!,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item['label']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  item['url']!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _apiKeyCtrl,
                obscureText: _obscureKey,
                decoration: InputDecoration(
                  labelText: 'API Key（本地 Ollama 可留空）',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _modelCtrl,
                      decoration: InputDecoration(
                        labelText: '模型名称（可拉取或手动填写）',
                        hintText: _format.defaultModel,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: FilledButton.tonalIcon(
                      onPressed: _fetchingModels ? null : _fetchAndPickModel,
                      icon: _fetchingModels
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_sync_rounded, size: 17),
                      label: const Text('拉取模型'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering_rounded, size: 17),
                label: const Text('测试连接'),
              ),
              if (_statusText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _statusText!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _statusSuccess ? Colors.green.shade700 : cs.error,
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
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _SearchableModelPickerDialog extends StatefulWidget {
  final List<String> models;
  final String currentModel;

  const _SearchableModelPickerDialog({
    required this.models,
    required this.currentModel,
  });

  @override
  State<_SearchableModelPickerDialog> createState() =>
      _SearchableModelPickerDialogState();
}

class _SearchableModelPickerDialogState
    extends State<_SearchableModelPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kw = _query.trim().toLowerCase();
    final filtered = kw.isEmpty
        ? widget.models
        : widget.models.where((m) => m.toLowerCase().contains(kw)).toList();

    return AlertDialog(
      title: Text('选择模型（共 ${widget.models.length} 个）'),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '输入关键词搜索模型（如 flash / deepseek / claude）',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('未找到匹配的模型'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final id = filtered[i];
                        final selected = id == widget.currentModel;
                        return ListTile(
                          dense: true,
                          title: Text(
                            id,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_circle, size: 18)
                              : null,
                          onTap: () => Navigator.of(ctx).pop(id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
