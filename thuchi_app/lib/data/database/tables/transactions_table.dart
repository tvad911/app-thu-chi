import 'package:drift/drift.dart';
import 'accounts_table.dart';
import 'categories_table.dart';
import 'debts_table.dart';

/// Transactions table - stores all financial transactions
import 'users_table.dart';

class Transactions extends Table {
  /// Primary key - auto increment
  IntColumn get id => integer().autoIncrement()();

  /// Transaction amount (always positive)
  RealColumn get amount => real()();

  /// Transaction date
  DateTimeColumn get date => dateTime()();

  /// Transaction type: income, expense, transfer
  TextColumn get type => text()();

  /// Optional note/description
  TextColumn get note => text().nullable()();

  /// Source account (required)
  IntColumn get accountId => integer().references(Accounts, #id)();

  /// Category (required for income/expense, null for transfer)
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();

  /// Destination account (only for transfer)
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();

  /// Linked debt ID (for debt repayment transactions)
  IntColumn get debtId => integer().nullable().references(Debts, #id)();

  /// Path to receipt image (local file path)
  TextColumn get imagePath => text().nullable()();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  /// Owner ID
  IntColumn get userId => integer().references(Users, #id)();
}
