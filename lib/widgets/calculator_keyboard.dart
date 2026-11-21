import 'package:flutter/material.dart';

import '../utils/math_evaluator.dart';

class CalculatorKeyboard extends StatelessWidget {
  final String expression;
  final String currencyPrefix;
  final ValueChanged<String> onExpressionChanged;
  final VoidCallback onSave;
  final Color accentColor;

  const CalculatorKeyboard({
    super.key,
    required this.expression,
    required this.currencyPrefix,
    required this.onExpressionChanged,
    required this.onSave,
    required this.accentColor,
  });

  bool get _hasOperator {
    final trimmed = expression.trim();
    if (trimmed.isEmpty) return false;
    final body = trimmed.startsWith('-') ? trimmed.substring(1) : trimmed;
    return body.contains('+') ||
        body.contains('−') ||
        body.contains('-') ||
        body.contains('×') ||
        body.contains('÷');
  }

  void _press(String token) {
    var expr = expression;
    const ops = {'+', '−', '×', '÷'};

    if (token == 'C') {
      onExpressionChanged('');
      return;
    }
    if (token == '⌫') {
      if (expr.isNotEmpty) {
        onExpressionChanged(expr.substring(0, expr.length - 1));
      }
      return;
    }
    if (token == '=') {
      final val = MathEvaluator.evaluate(expr);
      if (val != null) {
        final formatted = val.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
        onExpressionChanged(formatted.isEmpty ? '0' : formatted);
      }
      return;
    }

    if (ops.contains(token)) {
      if (expr.isEmpty) return;
      final last = expr[expr.length - 1];
      if (ops.contains(last)) {
        onExpressionChanged('${expr.substring(0, expr.length - 1)}$token');
      } else {
        onExpressionChanged('$expr$token');
      }
      return;
    }

    if (token == '.') {
      final parts = expr.split(RegExp(r'[+−×÷]'));
      final lastPart = parts.isEmpty ? '' : parts.last;
      if (lastPart.contains('.')) return;
      if (lastPart.isEmpty) {
        onExpressionChanged('${expr}0.');
      } else {
        onExpressionChanged('$expr.');
      }
      return;
    }

    onExpressionChanged('$expr$token');
  }

  @override
  Widget build(BuildContext context) {
    final evaluated = MathEvaluator.evaluate(expression);
    final isValidPositive = evaluated != null && evaluated > 0;
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Formula + real-time evaluated amount display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                expression.isEmpty ? '输入金额或算式' : expression,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$currencyPrefix${(evaluated ?? 0.0).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isValidPositive ? accentColor : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // 4-column calculator grid
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.9,
          children: [
            _CalcKey('7', onTap: () => _press('7')),
            _CalcKey('8', onTap: () => _press('8')),
            _CalcKey('9', onTap: () => _press('9')),
            _CalcKey('÷', isOperator: true, accent: accentColor, onTap: () => _press('÷')),
            _CalcKey('4', onTap: () => _press('4')),
            _CalcKey('5', onTap: () => _press('5')),
            _CalcKey('6', onTap: () => _press('6')),
            _CalcKey('×', isOperator: true, accent: accentColor, onTap: () => _press('×')),
            _CalcKey('1', onTap: () => _press('1')),
            _CalcKey('2', onTap: () => _press('2')),
            _CalcKey('3', onTap: () => _press('3')),
            _CalcKey('−', isOperator: true, accent: accentColor, onTap: () => _press('−')),
            _CalcKey('C', isDanger: true, onTap: () => _press('C')),
            _CalcKey('0', onTap: () => _press('0')),
            _CalcKey('.', onTap: () => _press('.')),
            _CalcKey('+', isOperator: true, accent: accentColor, onTap: () => _press('+')),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => _press('⌫'),
                  icon: const Icon(Icons.backspace_outlined, size: 18),
                  label: const Text('退格'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_hasOperator) ...[
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 46,
                  child: FilledButton.tonal(
                    onPressed: () => _press('='),
                    child: const Text(
                      '=',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 46,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: accentColor),
                  onPressed: isValidPositive ? onSave : null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text(
                    '完成保存',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CalcKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isOperator;
  final bool isDanger;
  final Color? accent;

  const _CalcKey(
    this.label, {
    required this.onTap,
    this.isOperator = false,
    this.isDanger = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isOperator
        ? (accent ?? cs.primary).withOpacity(0.14)
        : isDanger
            ? cs.errorContainer.withOpacity(0.55)
            : cs.surfaceContainerHighest.withOpacity(0.55);
    final fg = isOperator
        ? (accent ?? cs.primary)
        : isDanger
            ? cs.error
            : cs.onSurface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
