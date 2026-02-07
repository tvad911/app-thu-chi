import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Data class for event with its total spending
class EventWithSpending {
  final Event event;
  final double totalSpending;
  final int transactionCount;

  EventWithSpending({
    required this.event,
    required this.totalSpending,
    required this.transactionCount,
  });

  double get remainingBudget => event.budget - totalSpending;
  double get usagePercent => event.budget > 0 ? (totalSpending / event.budget) * 100 : 0;
}

/// Repository for Event CRUD operations
class EventRepository {
  final AppDatabase _db;

  EventRepository(this._db);

  /// Watch all active (not finished) events for a user
  Stream<List<Event>> watchActiveEvents(int userId) {
    return (_db.select(_db.events)
          ..where((e) => e.userId.equals(userId) & e.isFinished.equals(false))
          ..orderBy([(e) => OrderingTerm(expression: e.startDate, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Watch all events for a user
  Stream<List<Event>> watchAllEvents(int userId) {
    return (_db.select(_db.events)
          ..where((e) => e.userId.equals(userId))
          ..orderBy([(e) => OrderingTerm(expression: e.startDate, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Get single event by ID
  Future<Event?> getEvent(int id) {
    return (_db.select(_db.events)..where((e) => e.id.equals(id))).getSingleOrNull();
  }

  /// Get total spending for an event
  Future<double> getEventSpending(int eventId) async {
    final result = await (_db.select(_db.transactions)
          ..where((t) => t.eventId.equals(eventId) & t.type.equals('expense')))
        .get();
    return result.fold<double>(0, (sum, t) => sum + t.amount);
  }

  /// Get transaction count for an event
  Future<int> getEventTransactionCount(int eventId) async {
    final result = await (_db.select(_db.transactions)
          ..where((t) => t.eventId.equals(eventId)))
        .get();
    return result.length;
  }

  /// Get event with spending data
  Future<EventWithSpending> getEventWithSpending(int eventId) async {
    final event = await (_db.select(_db.events)..where((e) => e.id.equals(eventId))).getSingle();
    final spending = await getEventSpending(eventId);
    final count = await getEventTransactionCount(eventId);
    return EventWithSpending(event: event, totalSpending: spending, transactionCount: count);
  }

  /// Get all events with spending for a user
  Future<List<EventWithSpending>> getEventsWithSpending(int userId) async {
    final events = await (_db.select(_db.events)
          ..where((e) => e.userId.equals(userId))
          ..orderBy([(e) => OrderingTerm(expression: e.startDate, mode: OrderingMode.desc)]))
        .get();

    final result = <EventWithSpending>[];
    for (final event in events) {
      final spending = await getEventSpending(event.id);
      final count = await getEventTransactionCount(event.id);
      result.add(EventWithSpending(event: event, totalSpending: spending, transactionCount: count));
    }
    return result;
  }

  /// Create a new event
  Future<int> createEvent(EventsCompanion event) {
    return _db.into(_db.events).insert(event);
  }

  /// Update an event
  Future<bool> updateEvent(int id, EventsCompanion event) {
    return (_db.update(_db.events)..where((e) => e.id.equals(id))).write(event).then((rows) => rows > 0);
  }

  /// Delete an event
  Future<int> deleteEvent(int id) {
    return (_db.delete(_db.events)..where((e) => e.id.equals(id))).go();
  }

  /// Mark event as finished
  Future<void> finishEvent(int id) async {
    await (_db.update(_db.events)..where((e) => e.id.equals(id)))
        .write(const EventsCompanion(isFinished: Value(true)));
  }
}
