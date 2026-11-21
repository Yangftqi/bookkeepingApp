import 'package:intl/intl.dart';

class DateUtilsExt {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _monthFormat = DateFormat('yyyy年MM月');

  static String toDateStr(DateTime dt) => _dateFormat.format(dt);
  static String toDateTimeStr(DateTime dt) => _dateTimeFormat.format(dt);
  static String toMonthTitle(DateTime dt) => _monthFormat.format(dt);

  static DateTime parseDateStr(String dateStr) {
    final parts = dateStr.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static bool isDefaultWeekend(DateTime dt) {
    return dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday;
  }

  static bool isDefaultWeekendStr(String dateStr) {
    return isDefaultWeekend(parseDateStr(dateStr));
  }

  static DateTime startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static DateTime endOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999);

  /// Monday 00:00:00 of the week containing [dt]
  static DateTime startOfWeek(DateTime dt) {
    final diff = dt.weekday - DateTime.monday;
    return startOfDay(dt.subtract(Duration(days: diff)));
  }

  /// Sunday 23:59:59.999 of the week containing [dt]
  static DateTime endOfWeek(DateTime dt) {
    final start = startOfWeek(dt);
    return endOfDay(start.add(const Duration(days: 6)));
  }

  static DateTime startOfMonth(DateTime dt) => DateTime(dt.year, dt.month, 1);

  static DateTime endOfMonth(DateTime dt) =>
      endOfDay(DateTime(dt.year, dt.month + 1, 0));

  /// Enumerates all calendar days from [start] to [end] inclusive.
  static List<DateTime> enumerateDays(DateTime start, DateTime end) {
    final s = startOfDay(start);
    final e = startOfDay(end);
    if (e.isBefore(s)) return const [];
    final days = <DateTime>[];
    var cur = s;
    while (!cur.isAfter(e)) {
      days.add(cur);
      cur = DateTime(cur.year, cur.month, cur.day + 1);
    }
    return days;
  }
}
