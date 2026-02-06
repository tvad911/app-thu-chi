import 'package:drift/drift.dart';

/// Audit logs to track user actions
class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  /// Type of entity (e.g., 'Transaction', 'Account')
  TextColumn get entityType => text()();
  
  /// ID of the entity
  IntColumn get entityId => integer()();
  
  /// Action performed: CREATE, UPDATE, DELETE
  TextColumn get action => text()();
  
  /// JSON snapshot of data before change
  TextColumn get oldValue => text().nullable()();
  
  /// JSON snapshot of data after change
  TextColumn get newValue => text().nullable()();
  
  /// Description of the change
  TextColumn get description => text().nullable()();
  
  /// Timestamp
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}
