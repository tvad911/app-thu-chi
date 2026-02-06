import 'package:drift/drift.dart';
import '../database/app_database.dart';

class BudgetWithCategory {
  final Budget budget;
  final Category category;
  final double spentAmount;

  BudgetWithCategory({
    required this.budget, 
    required this.category,
    required this.spentAmount,
  });
  
  double get usagePercentage => budget.amountLimit > 0 ? (spentAmount / budget.amountLimit) : 0;
}

class BudgetRepository {
  final AppDatabase _db;

  BudgetRepository(this._db);

  /// Watch budgets with usage stats for a specific month
  Stream<List<BudgetWithCategory>> watchBudgetsWithUsage(int userId, int month, int year) {
    final start = DateTime(year, month, 1);
    // Correctly handle December -> January transition
    final end = (month == 12) 
      ? DateTime(year + 1, 1, 1) 
      : DateTime(year, month + 1, 1);

    final amountSum = _db.transactions.amount.sum();
    
    final query = _db.select(_db.budgets).join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.budgets.categoryId)),
      leftOuterJoin(_db.transactions, 
        _db.transactions.categoryId.equalsExp(_db.categories.id) &
        _db.transactions.date.isBiggerOrEqualValue(start) &
        _db.transactions.date.isSmallerThanValue(end) &
        _db.transactions.type.equals('expense')
      ),
    ]);
    
    query.where(_db.budgets.month.equals(month) & 
                _db.budgets.year.equals(year) &
                _db.categories.userId.equals(userId));
                
    query.groupBy([_db.budgets.id]);
    
    query.addColumns([amountSum]);

    return query.watch().map((rows) {
      return rows.map((row) {
         final budget = row.readTable(_db.budgets);
         final category = row.readTable(_db.categories);
         final spent = row.read(amountSum) ?? 0.0;
         
         return BudgetWithCategory(
           budget: budget,
           category: category,
           spentAmount: spent,
         );
      }).toList();
    });
  }

  /// Get a single budget by ID
  Future<Budget?> getBudgetById(int id) {
    return (_db.select(_db.budgets)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Create or update a budget
  Future<void> setBudget(BudgetsCompanion budget) async {
    // Check if budget exists for this category/month/year
    final existing = await (_db.select(_db.budgets)..where((b) => 
      b.categoryId.equals(budget.categoryId.value) &
      b.month.equals(budget.month.value) &
      b.year.equals(budget.year.value)
    )).getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.budgets)..where((b) => b.id.equals(existing.id)))
          .write(budget);
    } else {
      await _db.into(_db.budgets).insert(budget);
    }
  }

  /// Delete a budget
  Future<int> deleteBudget(int id) {
    return (_db.delete(_db.budgets)..where((t) => t.id.equals(id))).go();
  }
}
