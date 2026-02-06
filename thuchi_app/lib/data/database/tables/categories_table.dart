import 'package:drift/drift.dart';
import 'users_table.dart';

/// Categories table - stores income/expense categories
class Categories extends Table {
  /// Primary key - auto increment
  IntColumn get id => integer().autoIncrement()();

  /// Category name (e.g., "Ăn uống", "Tiền nhà")
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Category type: income or expense
  TextColumn get type => text()();

  /// Expense nature: fixed or variable (only for expense type)
  TextColumn get nature => text().nullable()();

  /// Icon codepoint from Material Icons
  IntColumn get iconCodepoint => integer().withDefault(const Constant(0xe5ca))();

  /// Sort order for display
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Whether this is a default category
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  /// Owner ID
  IntColumn get userId => integer().references(Users, #id)();
}
