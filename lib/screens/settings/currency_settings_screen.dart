import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../widgets/pin_dialog.dart';

class CurrencySettingsScreen extends ConsumerStatefulWidget {
  const CurrencySettingsScreen({super.key});

  @override
  ConsumerState<CurrencySettingsScreen> createState() =>
      _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState
    extends ConsumerState<CurrencySettingsScreen> {
  static const _presets = ['¥', '\$', '€', '£', '无符号'];
  late TextEditingController _customCtrl;

  @override
  void initState() {
    super.initState();
    final cur = ref.read(appControllerProvider).settings.currencySymbol;
    _customCtrl = TextEditingController(
      text: _presets.contains(cur) ? '' : cur,
    );
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _applySymbol(String symbol) async {
    final ok = await AuthGuard.requireAction(
      context,
      ref,
      ProtectedAction.modifyOrDelete,
      reason: '修改全局货币符号需要验证权限',
    );
    if (!ok || !mounted) return;
    await ref.read(appControllerProvider.notifier).updateCurrencySymbol(symbol);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换货币符号为：$symbol')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appControllerProvider).settings;
    final current = settings.currencySymbol;
    final display = settings.displayCurrency;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('全局货币符号')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '效果预览',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '-$display${128.50.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '全软件所有用户共享同一货币前缀符号',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '常用货币符号',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _presets.map((sym) {
                      return ChoiceChip(
                        label: Text(sym),
                        selected: current == sym,
                        onSelected: (_) {
                          _customCtrl.clear();
                          _applySymbol(sym);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '自定义前缀符号',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customCtrl,
                          decoration: const InputDecoration(
                            hintText: '例如：HK\$、RMB、JPY ',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: () {
                          final custom = _customCtrl.text.trim();
                          if (custom.isEmpty) return;
                          _applySymbol(custom);
                        },
                        child: const Text('应用'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
