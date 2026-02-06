import 'package:drift/drift.dart';
import 'categories_table.dart';

/// Budgets table - limits for categories
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  /// Linked category (Expense only)
  IntColumn get categoryId => integer().references(Categories, #id)();
  
  /// Budget limit amount
  RealColumn get amountLimit => real()();
  
  /// Month (1-12)
  IntColumn get month => integer()();
  
  /// Year (e.g. 2026)
  IntColumn get year => integer()();
  
  /// Auto renew for next month
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  
  /// Constraint to ensure one budget per category per month
  @override
  List<String> get customConstraints => [
    'UNIQUE(category_id, month, year)'
  ];
}
