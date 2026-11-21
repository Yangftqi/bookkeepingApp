import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_account.dart';
import '../providers/app_providers.dart';
import '../utils/pin_crypto.dart';

enum ProtectedAction {
  view,
  create,
  modifyOrDelete,
  masterOnly,
}

class AuthGuard {
  /// Enforces the 4-level PIN state machine & cross-user anti-escalation rule.
  /// Returns `true` if authorized, `false` if cancelled/failed.
  static Future<bool> requireAction(
    BuildContext context,
    WidgetRef ref,
    ProtectedAction action, {
    UserAccount? targetUser,
    String? reason,
  }) async {
    final state = ref.read(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);

    if (action == ProtectedAction.masterOnly) {
      final ok = await showPinVerifyDialog(
        context: context,
        title: '验证超级管理员主 PIN 码',
        subtitle: reason ?? '该敏感操作需要验证超级管理员主密码',
        validator: controller.verifyMasterPin,
      );
      return ok;
    }

    final current = state.currentUser;
    final effectiveUser = targetUser ?? current;
    if (effectiveUser == null) return true;

    // Cross-user anti-escalation rule:
    // If operating on ANOTHER user who has authLevel > 0, ALWAYS require target user's PIN (or Master PIN)!
    final isCrossUser =
        targetUser != null && current != null && targetUser.id != current.id;
    if (isCrossUser) {
      if (targetUser.authLevel <= 0) return true;
      return showPinVerifyDialog(
        context: context,
        title: '验证用户「${targetUser.name}」的 PIN 码',
        subtitle: reason ?? '跨用户操作受保护账号，请输入该用户 PIN 码或超级管理员主 PIN 码',
        validator: (pin) => controller.verifyUserOrMasterPin(pin, targetUser),
      );
    }

    // Current user permission matrix
    final level = effectiveUser.authLevel;
    bool needsPin = false;
    switch (action) {
      case ProtectedAction.view:
        needsPin = level >= 3;
        break;
      case ProtectedAction.create:
        needsPin = level >= 2;
        break;
      case ProtectedAction.modifyOrDelete:
        needsPin = level >= 1;
        break;
      case ProtectedAction.masterOnly:
        needsPin = true;
        break;
    }

    if (!needsPin || state.isSessionUnlocked) return true;

    final verified = await showPinVerifyDialog(
      context: context,
      title: '请输入 PIN 码解锁',
      subtitle: reason ?? '当前用户「${effectiveUser.name}」已开启${effectiveUser.authLevelLabel}（亦可使用超级管理员主 PIN 码）',
      validator: (pin) => controller.verifyUserOrMasterPin(pin, effectiveUser),
    );
    if (verified) {
      controller.setSessionUnlocked(true);
    }
    return verified;
  }
}

/// Shows a custom numeric 4~6 digit PIN verification dialog.
Future<bool> showPinVerifyDialog({
  required BuildContext context,
  required String title,
  String? subtitle,
  required bool Function(String pin) validator,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _PinVerifyDialog(
      title: title,
      subtitle: subtitle,
      validator: validator,
    ),
  );
  return result == true;
}

/// Shows a two-step PIN creation/reset dialog returning the chosen 4~6 digit PIN, or null if cancelled.
Future<String?> showPinSetupDialog({
  required BuildContext context,
  required String title,
  String? subtitle,
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _PinSetupDialog(title: title, subtitle: subtitle),
  );
}

class PinPadWidget extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final String submitLabel;
  final String? errorText;

  const PinPadWidget({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onSubmit,
    this.submitLabel = '确认',
    this.errorText,
  });

  void _append(String digit) {
    if (value.length >= 6) return;
    onChanged('$value$digit');
  }

  void _backspace() {
    if (value.isEmpty) return;
    onChanged(value.substring(0, value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canSubmit = PinCrypto.isValidPinFormat(value);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 6-slot visual indicator (4 required, up to 6 digits)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) {
            final filled = i < value.length;
            final requiredSlot = i < 4;
            return Container(
              width: 34,
              height: 42,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: filled
                      ? cs.primary
                      : (requiredSlot
                          ? cs.outline
                          : cs.outlineVariant.withOpacity(0.5)),
                  width: filled ? 2 : 1,
                ),
                color: filled ? cs.primary.withOpacity(0.1) : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: filled
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary,
                      ),
                    )
                  : null,
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          errorText ?? '请输入 4~6 位数字 PIN 码',
          style: TextStyle(
            fontSize: 12,
            color: errorText != null ? cs.error : cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 260,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.55,
            children: [
              for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                _PadKey(label: d, onTap: () => _append(d)),
              _PadKey(
                label: '清空',
                fontSize: 13,
                onTap: () => onChanged(''),
              ),
              _PadKey(label: '0', onTap: () => _append('0')),
              _PadKey(
                icon: Icons.backspace_outlined,
                onTap: _backspace,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 260,
          child: FilledButton(
            onPressed: canSubmit ? onSubmit : null,
            child: Text(submitLabel),
          ),
        ),
      ],
    );
  }
}

class _PadKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final double fontSize;
  final VoidCallback onTap;

  const _PadKey({
    this.label,
    this.icon,
    this.fontSize = 20,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withOpacity(0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: icon != null
              ? Icon(icon, size: 20)
              : Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

class _PinVerifyDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool Function(String pin) validator;

  const _PinVerifyDialog({
    required this.title,
    this.subtitle,
    required this.validator,
  });

  @override
  State<_PinVerifyDialog> createState() => _PinVerifyDialogState();
}

class _PinVerifyDialogState extends State<_PinVerifyDialog> {
  String _pin = '';
  String? _error;

  void _submit() {
    if (widget.validator(_pin)) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = 'PIN 码错误，请重试';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.subtitle != null) ...[
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
            ],
            PinPadWidget(
              value: _pin,
              errorText: _error,
              onChanged: (v) => setState(() {
                _pin = v;
                _error = null;
              }),
              onSubmit: _submit,
              submitLabel: '验证解锁',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

class _PinSetupDialog extends StatefulWidget {
  final String title;
  final String? subtitle;

  const _PinSetupDialog({required this.title, this.subtitle});

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  String _firstPin = '';
  String _input = '';
  bool _confirmStep = false;
  String? _error;

  void _submit() {
    if (!_confirmStep) {
      setState(() {
        _firstPin = _input;
        _input = '';
        _confirmStep = true;
        _error = null;
      });
    } else {
      if (_input == _firstPin) {
        Navigator.of(context).pop(_firstPin);
      } else {
        setState(() {
          _error = '两次输入的 PIN 码不一致，请重新设置';
          _firstPin = '';
          _input = '';
          _confirmStep = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _confirmStep ? '再次输入以确认' : widget.title,
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.subtitle != null && !_confirmStep) ...[
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
            ],
            PinPadWidget(
              value: _input,
              errorText: _error,
              onChanged: (v) => setState(() {
                _input = v;
                _error = null;
              }),
              onSubmit: _submit,
              submitLabel: _confirmStep ? '完成设置' : '下一步',
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
