import 'package:drift/drift.dart';

import 'transactions_table.dart';
import 'debts_table.dart';
import 'bills_table.dart';

/// Attachments table for file metadata tracking
/// Files can be attached to transactions, debts, or bills
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  // Entity references - at least one must be set
  IntColumn get transactionId => integer().nullable().references(Transactions, #id, onDelete: KeyAction.cascade)();
  IntColumn get debtId => integer().nullable().references(Debts, #id, onDelete: KeyAction.cascade)();
  IntColumn get billId => integer().nullable().references(Bills, #id, onDelete: KeyAction.cascade)();
  
  // File information
  TextColumn get fileName => text()(); // Original filename
  TextColumn get fileType => text()(); // MIME type: image/jpeg, application/pdf, etc.
  IntColumn get fileSize => integer()(); // Size in bytes
  TextColumn get localPath => text()(); // Relative path in app directory
  
  // Google Drive sync
  TextColumn get driveFileId => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))(); // PENDING, SYNCED, ERROR
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  TextColumn get syncError => text().nullable()(); // Error message if sync failed
  
  // Timestamps
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
