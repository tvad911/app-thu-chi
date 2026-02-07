import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuchi_app/data/database/app_database.dart';
import 'package:thuchi_app/data/repositories/event_repository.dart';

void main() {
  late AppDatabase db;
  late EventRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = EventRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('EventRepository Tests', () {
    test('CRUD Event', () async {
      final now = DateTime.now();

      // Create User first to satisfy foreign key
      final userId = await db.into(db.users).insert(
        UsersCompanion.insert(
          username: 'u_event',
          passwordHash: 'pw',
          displayName: 'User Event',
          createdAt: Value(now),
        ),
      );

      // Create
      final newEvent = EventsCompanion.insert(
        name: 'Summer Trip',
        startDate: now, // required, raw type
        userId: userId,
        // isFinished default false
      );
      final id = await repository.createEvent(newEvent);
      expect(id, isPositive);

      // Read
      final event = await repository.getEvent(id);
      expect(event, isNotNull);
      expect(event!.name, 'Summer Trip');

      // Update
      // Use companion for update
      final updatedCompanion = event.toCompanion(true).copyWith(name: const Value('Winter Trip'));
      await repository.updateEvent(id, updatedCompanion);
      
      final updated = await repository.getEvent(id);
      expect(updated!.name, 'Winter Trip');

      // Delete
      await repository.deleteEvent(id);
      final deleted = await repository.getEvent(id);
      expect(deleted, isNull);
    });

    test('getEventWithSpending calculates spending correctly', () async {
      // 1. Create User
      final userId = await db.into(db.users).insert(
        UsersCompanion.insert(
          username: 'user1', 
          passwordHash: 'pw', 
          displayName: 'U1',
          createdAt: Value(DateTime.now())
        ),
      );
      
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          name: 'Acc',
          balance: const Value(0.0),
          currencyCode: Value('VND'),
          type: 'cash',
          userId: userId,
        ),
      );

      // 2. Create Event
      final eventId = await repository.createEvent(
        EventsCompanion.insert(
          name: 'Test Event',
          startDate: DateTime.now(), // required, raw type
          budget: const Value(1000000.0),
          userId: userId,
        ),
      );

      // 3. Create Transactions linked to this event
      final catId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'c1', 
          type: 'expense', 
          iconCodepoint: const Value(0), // has default, use Value
          userId: userId,
        ),
      );

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: 200000,
          type: 'expense',
          date: DateTime.now(),
          categoryId: Value(catId),
          userId: userId,
          accountId: accountId,
          eventId: Value(eventId), // Link to event
        ),
      );
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: 300000,
          type: 'expense',
          date: DateTime.now(),
          categoryId: Value(catId),
          userId: userId,
          accountId: accountId,
          eventId: Value(eventId),
        ),
      );

      // Act
      final eventWithSpending = await repository.getEventWithSpending(eventId);

      // Assert
      expect(eventWithSpending.totalSpending, 500000.0);
      expect(eventWithSpending.transactionCount, 2);
      expect(eventWithSpending.remainingBudget, 500000.0); // 1M - 500k
    });
  });
}
