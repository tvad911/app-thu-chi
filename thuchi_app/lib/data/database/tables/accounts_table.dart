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

  /// Whether this account is archived
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// Currency code (ISO 4217, defaults to VND)
  TextColumn get currencyCode => text().withDefault(const Constant('VND'))();

  /// Whether this account is hidden in privacy mode
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  /// When the account was created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last updated timestamp
  DateTimeColumn get updatedAt => dateTime().nullable()();
  /// Owner ID
  IntColumn get userId => integer().references(Users, #id)();
}
