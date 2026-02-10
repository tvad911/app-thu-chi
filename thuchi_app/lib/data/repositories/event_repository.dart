import 'package:drift/drift.dart';
import 'dart:convert';

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
  Future<int> createEvent(EventsCompanion event) async {
    final id = await _db.into(_db.events).insert(event);

    await _logChange(
      entityType: 'Event',
      entityId: id,
      action: 'CREATE',
      newValue: _companionToMap(event)..['id'] = id,
      description: 'New event: ${event.name.value}',
    );

    return id;
  }

  /// Update an event
  Future<bool> updateEvent(int id, EventsCompanion event) async {
    final oldEvent = await getEvent(id);
    final rows = await (_db.update(_db.events)..where((e) => e.id.equals(id))).write(event);

    if (rows > 0) {
      final updatedEvent = await getEvent(id);
      await _logChange(
        entityType: 'Event',
        entityId: id,
        action: 'UPDATE',
        oldValue: oldEvent != null ? _eventToMap(oldEvent) : null,
        newValue: updatedEvent != null ? _eventToMap(updatedEvent) : null,
        description: 'Updated event: ${oldEvent?.name}',
      );
    }

    return rows > 0;
  }

  /// Delete an event
  Future<int> deleteEvent(int id) async {
    final oldEvent = await getEvent(id);
    final rows = await (_db.delete(_db.events)..where((e) => e.id.equals(id))).go();

    if (rows > 0) {
      await _logChange(
        entityType: 'Event',
        entityId: id,
        action: 'DELETE',
        oldValue: oldEvent != null ? _eventToMap(oldEvent) : null,
        description: 'Deleted event: ${oldEvent?.name}',
      );
    }

    return rows;
  }

  /// Mark event as finished
  Future<void> finishEvent(int id) async {
    await (_db.update(_db.events)..where((e) => e.id.equals(id)))
        .write(const EventsCompanion(isFinished: Value(true)));

    await _logChange(
      entityType: 'Event',
      entityId: id,
      action: 'FINISH',
      newValue: {'isFinished': true},
      description: 'Finished event #$id',
    );
  }

  /// Get all transactions belonging to an event
  Future<List<Transaction>> getTransactionsForEvent(int eventId) async {
    return (_db.select(_db.transactions)
          ..where((t) => t.eventId.equals(eventId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  // -- Audit Log Helpers --

  Map<String, dynamic> _eventToMap(Event row) {
    return {
      'id': row.id,
      'name': row.name,
      'budget': row.budget,
      'startDate': row.startDate.toIso8601String(),
      'endDate': row.endDate?.toIso8601String(),
      'isFinished': row.isFinished,
      'userId': row.userId,
    };
  }

  Map<String, dynamic> _companionToMap(EventsCompanion c) {
    return {
      if (c.name.present) 'name': c.name.value,
      if (c.budget.present) 'budget': c.budget.value,
      if (c.startDate.present) 'startDate': c.startDate.value.toIso8601String(),
      if (c.endDate.present) 'endDate': c.endDate.value?.toIso8601String(),
      if (c.isFinished.present) 'isFinished': c.isFinished.value,
      if (c.userId.present) 'userId': c.userId.value,
    };
  }

  Future<void> _logChange({
    required String entityType,
    required int entityId,
    required String action,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String? description,
  }) async {
    await _db.into(_db.auditLogs).insert(AuditLogsCompanion(
      entityType: Value(entityType),
      entityId: Value(entityId),
      action: Value(action),
      oldValue: Value(oldValue != null ? jsonEncode(oldValue) : null),
      newValue: Value(newValue != null ? jsonEncode(newValue) : null),
      description: Value(description),
      timestamp: Value(DateTime.now()),
    ));
  }
}
