import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../providers/app_providers.dart';
import '../utils/currency_utils.dart';
import 'notification_service.dart';

/// Service to check budgets and trigger alerts when spending exceeds thresholds
class BudgetAlertService {
  final AppDatabase _db;
  final NotificationService _notificationService;

  BudgetAlertService(this._db, this._notificationService);

  /// Check all budgets for a user in the current month and fire alerts if needed
  Future<List<BudgetAlert>> checkBudgets(int userId) async {
    final now = DateTime.now();
    final alerts = <BudgetAlert>[];

    // Get all budgets for current month
    final budgets = await (_db.select(_db.budgets)
          ..where((b) =>
              b.month.equals(now.month) & b.year.equals(now.year)))
        .get();

    for (final budget in budgets) {
      // Get category name
      final category = await (_db.select(_db.categories)
            ..where((c) => c.id.equals(budget.categoryId)))
          .getSingleOrNull();
      if (category == null) continue;

      // Calculate total spending for this category this month
      final firstDay = DateTime(now.year, now.month, 1);
      final lastDay = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      
      final transactions = await (_db.select(_db.transactions)
            ..where((t) => t.categoryId.equals(budget.categoryId) & t.type.equals('expense')))
          .get();

      // Filter by date client-side (avoids Drift API issues with date comparisons)
      final monthTransactions = transactions
          .where((t) => !t.date.isBefore(firstDay) && !t.date.isAfter(lastDay))
          .toList();

      final totalSpent = monthTransactions.fold<double>(0, (sum, t) => sum + t.amount);
      final usagePercent = budget.amountLimit > 0 ? (totalSpent / budget.amountLimit) * 100 : 0.0;

      if (usagePercent >= 90) {
        final alert = BudgetAlert(
          categoryName: category.name,
          amountLimit: budget.amountLimit,
          totalSpent: totalSpent,
          usagePercent: usagePercent,
        );
        alerts.add(alert);

        // Fire notification
        await _notificationService.showInstant(
          id: 1000 + budget.id,
          title: '⚠️ Cảnh báo ngân sách: ${category.name}',
          body: 'Đã chi ${CurrencyUtils.formatVND(totalSpent)} / ${CurrencyUtils.formatVND(budget.amountLimit)} '
              '(${usagePercent.toStringAsFixed(0)}%)',
        );
      }
    }

    return alerts;
  }
}

/// Data class representing a budget alert
class BudgetAlert {
  final String categoryName;
  final double amountLimit;
  final double totalSpent;
  final double usagePercent;

  BudgetAlert({
    required this.categoryName,
    required this.amountLimit,
    required this.totalSpent,
    required this.usagePercent,
  });

  bool get isOverBudget => usagePercent >= 100;
}

/// Provider for BudgetAlertService
final budgetAlertServiceProvider = Provider<BudgetAlertService>((ref) {
  final db = ref.watch(databaseProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return BudgetAlertService(db, notificationService);
});
