import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/seed_data.dart';
import '../../providers/app_providers.dart';
import '../../services/llm_service.dart';
import '../../widgets/pin_dialog.dart';

Future<void> showLlmConfigDialog(BuildContext context, WidgetRef ref) async {
  final ok = await AuthGuard.requireAction(
    context,
    ref,
    ProtectedAction.modifyOrDelete,
    reason: '修改全局大模型 API 配置需要验证权限',
  );
  if (!ok || !context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => const _LlmConfigDialog(),
  );
}

class _LlmConfigDialog extends ConsumerStatefulWidget {
  const _LlmConfigDialog();

  @override
  ConsumerState<_LlmConfigDialog> createState() => _LlmConfigDialogState();
}

class _LlmConfigDialogState extends ConsumerState<_LlmConfigDialog> {
  late TextEditingController _baseUrlCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _modelCtrl;
  bool _obscureKey = true;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appControllerProvider).settings;
    _baseUrlCtrl = TextEditingController(text: settings.llmBaseUrl);
    _apiKeyCtrl = TextEditingController(text: settings.llmApiKey);
    _modelCtrl = TextEditingController(text: settings.llmModelName);
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final reply = await LlmService.testConnection(
        baseUrl: _baseUrlCtrl.text,
        apiKey: _apiKeyCtrl.text,
        modelName: _modelCtrl.text,
      );
      if (mounted) {
        setState(() {
          _testing = false;
          _testSuccess = true;
          _testResult = '连接成功！模型回复：$reply';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _testSuccess = false;
          _testResult = '连接失败：$e';
        });
      }
    }
  }

  Future<void> _save() async {
    await ref.read(appControllerProvider.notifier).updateLlmConfig(
          baseUrl: _baseUrlCtrl.text,
          apiKey: _apiKeyCtrl.text,
          modelName: _modelCtrl.text,
        );
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('全局大模型 API 配置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('全局大模型 API 配置'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '快捷填充模板（全软件所有用户共用）：',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: SeedData.llmProviderTemplates.map((tpl) {
                  return ActionChip(
                    label: Text(
                      tpl['label']!,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _baseUrlCtrl.text = tpl['baseUrl']!;
                        _modelCtrl.text = tpl['model']!;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _baseUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.deepseek.com/v1',
                  border: OutlineInputBorder(),
                  isDense: true,
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
              TextField(
                controller: _modelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Model Name',
                  hintText: 'deepseek-chat / gpt-4o-mini / qwen-plus',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _test,
                    icon: _testing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering_rounded, size: 18),
                    label: const Text('测试连接'),
                  ),
                ],
              ),
              if (_testResult != null) ...[
                const SizedBox(height: 8),
                Text(
                  _testResult!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _testSuccess ? Colors.green.shade700 : cs.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('保存配置'),
        ),
      ],
    );
  }
}
