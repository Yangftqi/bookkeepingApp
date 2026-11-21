import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/user_switcher_sheet.dart';

class LockOverlayScreen extends ConsumerStatefulWidget {
  const LockOverlayScreen({super.key});

  @override
  ConsumerState<LockOverlayScreen> createState() => _LockOverlayScreenState();
}

class _LockOverlayScreenState extends ConsumerState<LockOverlayScreen> {
  String _pin = '';
  String? _error;

  void _unlock() {
    final state = ref.read(appControllerProvider);
    final user = state.currentUser;
    if (user == null) return;
    final ok = ref
        .read(appControllerProvider.notifier)
        .verifyUserOrMasterPin(_pin, user);
    if (ok) {
      ref.read(appControllerProvider.notifier).setSessionUnlocked(true);
    } else {
      setState(() {
        _error = 'PIN 码不正确（支持本用户 PIN 码或超级管理员主 PIN 码）';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final user = state.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('基米记账 · 隐私保护'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: () => showUserSwitcherSheet(context, ref),
              icon: const Icon(Icons.switch_account_rounded, size: 18),
              label: const Text('切换其他用户'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.lock_rounded,
                    size: 34,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '用户「${user?.name ?? ''}」已锁定',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '请输入 PIN 码解锁',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                PinPadWidget(
                  value: _pin,
                  errorText: _error,
                  onChanged: (v) => setState(() {
                    _pin = v;
                    _error = null;
                  }),
                  onSubmit: _unlock,
                  submitLabel: '解锁进入',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
