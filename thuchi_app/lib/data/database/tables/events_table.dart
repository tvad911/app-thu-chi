import 'package:drift/drift.dart';
import 'users_table.dart';

/// Events table - tracks special events/trips for separate expense tracking
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Event name (e.g., "Du lịch Thái Lan", "Đám cưới")
  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// Start date of the event
  DateTimeColumn get startDate => dateTime()();

  /// End date (nullable for open-ended events)
  DateTimeColumn get endDate => dateTime().nullable()();

  /// Whether the event has been marked as finished
  BoolColumn get isFinished => boolean().withDefault(const Constant(false))();

  /// Planned budget for the event
  RealColumn get budget => real().withDefault(const Constant(0))();

  /// Optional note/description
  TextColumn get note => text().nullable()();

  /// Owner ID
  IntColumn get userId => integer().references(Users, #id)();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
