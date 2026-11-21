import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../widgets/pin_dialog.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0; // 0: set master PIN, 1: confirm master PIN, 2: first username
  String _firstPin = '';
  String _currentPin = '';
  String? _pinError;
  final TextEditingController _nameController = TextEditingController();
  String? _nameError;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handlePinSubmit() {
    if (_step == 0) {
      setState(() {
        _firstPin = _currentPin;
        _currentPin = '';
        _step = 1;
        _pinError = null;
      });
    } else if (_step == 1) {
      if (_currentPin != _firstPin) {
        setState(() {
          _pinError = '两次输入的主 PIN 码不一致，请重新设置';
          _firstPin = '';
          _currentPin = '';
          _step = 0;
        });
      } else {
        setState(() {
          _step = 2;
          _pinError = null;
        });
      }
    }
  }

  Future<void> _finishOnboarding() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = '请输入您的第一个记账用户名');
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
    });
    await ref.read(appControllerProvider.notifier).completeOnboarding(
          masterPin: _firstPin,
          firstUserName: name,
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEEF2FF), Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                            ),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '欢迎使用基米记账',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _step == 0
                              ? '步骤 1/3：设置 4~6 位超级管理员主 PIN 码'
                              : _step == 1
                                  ? '步骤 2/3：再次输入主 PIN 码以确认'
                                  : '步骤 3/3：输入第一个记账用户名',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (_step < 2)
                          PinPadWidget(
                            value: _currentPin,
                            errorText: _pinError,
                            onChanged: (v) => setState(() {
                              _currentPin = v;
                              _pinError = null;
                            }),
                            onSubmit: _handlePinSubmit,
                            submitLabel: _step == 0 ? '下一步' : '确认主密码',
                          )
                        else ...[
                          TextField(
                            controller: _nameController,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: '第一个用户名',
                              hintText: '例如：小明、主账本',
                              errorText: _nameError,
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onSubmitted: (_) => _finishOnboarding(),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() {
                                            _step = 0;
                                            _firstPin = '';
                                            _currentPin = '';
                                          }),
                                  child: const Text('重设主密码'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : _finishOnboarding,
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.rocket_launch_rounded),
                                  label: const Text('开启记账之旅'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
