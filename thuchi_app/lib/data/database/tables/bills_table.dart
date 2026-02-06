import 'package:drift/drift.dart';

import 'users_table.dart';
import 'categories_table.dart';

/// Bills table for recurring and one-time bill tracking
class Bills extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  // Bill information
  TextColumn get title => text().withLength(min: 1, max: 100)();
  RealColumn get amount => real()();
  DateTimeColumn get dueDate => dateTime()();
  TextColumn get repeatCycle => text()(); // NONE, WEEKLY, MONTHLY, YEARLY
  IntColumn get notifyBefore => integer().withDefault(const Constant(3))();
  
  // Status
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  
  // References
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  TextColumn get userId => text().references(Users, #id)();
  
  // Additional info
  TextColumn get note => text().nullable()();
  
  // Timestamps
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
