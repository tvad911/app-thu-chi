import 'package:intl/intl.dart';

/// Utility class for date formatting and manipulation
class DateUtils {
  DateUtils._();

  static final _dayMonthFormat = DateFormat('dd/MM');
  static final _fullDateFormat = DateFormat('dd/MM/yyyy');
  static final _monthYearFormat = DateFormat('MM/yyyy');
  static final _dayNameFormat = DateFormat('EEEE', 'vi_VN');

  /// Format to dd/MM (e.g., "05/02")
  static String formatDayMonth(DateTime date) {
    return _dayMonthFormat.format(date);
  }

  /// Format to dd/MM/yyyy (e.g., "05/02/2026")
  static String formatFullDate(DateTime date) {
    return _fullDateFormat.format(date);
  }

  /// Format to MM/yyyy (e.g., "02/2026")
  static String formatMonthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }

  /// Get Vietnamese day name (e.g., "Thứ Tư")
  static String getDayName(DateTime date) {
    return _dayNameFormat.format(date);
  }

  /// Format relative date (Hôm nay, Hôm qua, etc.)
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    
    final difference = today.difference(targetDate).inDays;
    
    if (difference == 0) {
      return 'Hôm nay';
    } else if (difference == 1) {
      return 'Hôm qua';
    } else if (difference == -1) {
      return 'Ngày mai';
    } else if (difference > 0 && difference < 7) {
      return '$difference ngày trước';
    } else if (difference < 0 && difference > -7) {
      return '${-difference} ngày tới';
    } else {
      return formatFullDate(date);
    }
  }

  /// Get start of month
  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Get end of month
  static DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59);
  }

  /// Get start of year
  static DateTime startOfYear(DateTime date) {
    return DateTime(date.year, 1, 1);
  }

  /// Get end of year
  static DateTime endOfYear(DateTime date) {
    return DateTime(date.year, 12, 31, 23, 59, 59);
  }

  /// Check if two dates are the same day
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  /// Get list of months between two dates
  static List<DateTime> getMonthsBetween(DateTime start, DateTime end) {
    final months = <DateTime>[];
    var current = DateTime(start.year, start.month, 1);
    final endMonth = DateTime(end.year, end.month, 1);
    
    while (current.isBefore(endMonth) || current.isAtSameMomentAs(endMonth)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
    
    return months;
  }
}
