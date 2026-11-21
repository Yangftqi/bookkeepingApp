/// Safe recursive-descent arithmetic expression evaluator supporting +, -, ×, ÷
/// and decimal numbers. Rounds final currency value to 2 decimal places.
class MathEvaluator {
  static double? evaluate(String rawExpression) {
    final normalized = rawExpression
        .replaceAll(' ', '')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-');
    if (normalized.isEmpty) return null;

    // Trim trailing dangling operators so live preview works while typing
    var expr = normalized;
    while (expr.isNotEmpty && '+-*/.'.contains(expr[expr.length - 1])) {
      expr = expr.substring(0, expr.length - 1);
    }
    if (expr.isEmpty) return null;

    try {
      final parser = _ExprParser(expr);
      final result = parser.parseExpression();
      if (!parser.isAtEnd || result.isNaN || result.isInfinite) {
        return null;
      }
      return double.parse(result.toStringAsFixed(2));
    } catch (_) {
      return null;
    }
  }
}

class _ExprParser {
  final String input;
  int pos = 0;

  _ExprParser(this.input);

  bool get isAtEnd => pos >= input.length;
  String get current => input[pos];

  double parseExpression() {
    var value = parseTerm();
    while (!isAtEnd && (current == '+' || current == '-')) {
      final op = current;
      pos++;
      final right = parseTerm();
      value = op == '+' ? value + right : value - right;
    }
    return value;
  }

  double parseTerm() {
    var value = parseFactor();
    while (!isAtEnd && (current == '*' || current == '/')) {
      final op = current;
      pos++;
      final right = parseFactor();
      if (op == '*') {
        value *= right;
      } else {
        if (right == 0) {
          throw const FormatException('Division by zero');
        }
        value /= right;
      }
    }
    return value;
  }

  double parseFactor() {
    if (!isAtEnd && (current == '+' || current == '-')) {
      final op = current;
      pos++;
      final value = parseFactor();
      return op == '-' ? -value : value;
    }
    return parseNumber();
  }

  double parseNumber() {
    final start = pos;
    var hasDot = false;
    while (!isAtEnd) {
      final c = current;
      if (c == '.') {
        if (hasDot) break;
        hasDot = true;
        pos++;
      } else if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) {
        pos++;
      } else {
        break;
      }
    }
    if (start == pos) {
      throw const FormatException('Expected number');
    }
    return double.parse(input.substring(start, pos));
  }
}
