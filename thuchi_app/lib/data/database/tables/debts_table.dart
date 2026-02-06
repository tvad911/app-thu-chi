import 'package:drift/drift.dart';
import 'users_table.dart';

/// Debts table - stores lending/borrowing records
class Debts extends Table {
  /// Primary key - auto increment
  IntColumn get id => integer().autoIncrement()();

  /// Person name (lender or borrower)
  TextColumn get person => text().withLength(min: 1, max: 100)();

  /// Total debt amount
  RealColumn get totalAmount => real()();

  /// Amount of principal remaining (renamed from paidAmount for clarity)
  RealColumn get remainingAmount => real()();

  /// Interest rate (e.g., 12.5 for 12.5%)
  RealColumn get interestRate => real().withDefault(const Constant(0))();

  /// Interest type: PERCENT_YEAR, PERCENT_MONTH, FIXED
  TextColumn get interestType => text().withDefault(const Constant('PERCENT_YEAR'))();

  /// Start date of the debt
  DateTimeColumn get startDate => dateTime()();

  /// Due date (optional)
  DateTimeColumn get dueDate => dateTime().nullable()();

  /// Number of days before due date to send notification
  IntColumn get notifyDays => integer().withDefault(const Constant(3))();

  /// Debt type: lend or borrow
  TextColumn get type => text()();

  /// Optional note
  TextColumn get note => text().nullable()();

  /// Whether debt is fully paid
  BoolColumn get isFinished => boolean().withDefault(const Constant(false))();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last updated timestamp  
  DateTimeColumn get updatedAt => dateTime().nullable()();
  /// Owner ID
  IntColumn get userId => integer().references(Users, #id)();
}
