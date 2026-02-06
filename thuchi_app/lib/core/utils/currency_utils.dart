import 'package:intl/intl.dart';

/// Utility class for currency formatting
class CurrencyUtils {
  CurrencyUtils._();

  static final _vndFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  /// Format amount to VND currency string
  /// e.g., 1500000 -> "1.500.000 ₫"
  static String formatVND(double amount) {
    return _vndFormat.format(amount);
  }
  
  /// Alias for formatVND
  static String format(double? amount) {
    return _vndFormat.format(amount ?? 0);
  }

  /// Format amount without currency symbol
  /// e.g., 1500000 -> "1.500.000"
  static String formatNumber(double amount) {
    return NumberFormat('#,###', 'vi_VN').format(amount);
  }

  /// Format amount in compact form
  /// e.g., 1500000 -> "1,5 Tr"
  static String formatCompact(double amount) {
    if (amount.abs() >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)} Tỷ';
    } else if (amount.abs() >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)} Tr';
    } else if (amount.abs() >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)} K';
    }
    return amount.toStringAsFixed(0);
  }

  /// Parse string to double, handling Vietnamese number format
  static double? parse(String value) {
    if (value.isEmpty) return null;
    
    // Remove currency symbol and spaces
    final cleaned = value
        .replaceAll('₫', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .replaceAll(' ', '')
        .trim();
    
    return double.tryParse(cleaned);
  }

  /// Format amount with sign (+ or -)
  static String formatWithSign(double amount) {
    final prefix = amount >= 0 ? '+' : '';
    return '$prefix${formatVND(amount)}';
  }
}
