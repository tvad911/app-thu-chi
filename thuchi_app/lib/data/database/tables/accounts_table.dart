import 'package:drift/drift.dart';
import 'users_table.dart';

/// Accounts table - stores wallet/account information
class Accounts extends Table {
  /// Primary key - auto increment
  IntColumn get id => integer().autoIncrement()();

  /// Account name (e.g., "Ví tiền mặt", "Vietcombank")
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Current balance
  RealColumn get balance => real().withDefault(const Constant(0))();

  /// Account type: cash, bank, credit
  TextColumn get type => text()();

  /// Color for visual identification (hex format)
  TextColumn get color => text().nullable()();

  /// Whether account is archived (hidden but not deleted)
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last updated timestamp
  DateTimeColumn get updatedAt => dateTime().nullable()();
  /// Owner ID
  IntColumn get userId => integer().references(Users, #id)();
}
