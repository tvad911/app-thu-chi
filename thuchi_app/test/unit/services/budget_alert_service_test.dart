import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuchi_app/core/services/budget_alert_service.dart';
import 'package:thuchi_app/core/services/notification_service.dart';
import 'package:thuchi_app/data/database/app_database.dart';

// Mock NotificationService
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late AppDatabase db;
  late MockNotificationService mockNotificationService;
  late BudgetAlertService service;

  setUp(() {
    // In-memory database for testing
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mockNotificationService = MockNotificationService();
    service = BudgetAlertService(db, mockNotificationService);
  });

  tearDown(() async {
    await db.close();
  });

  group('BudgetAlertService Tests', () {
    test('Should trigger alert when spending > 90% of budget', () async {
      // Arrange
      final now = DateTime.now();
      
      // 1. Create User
      final userId = await db.into(db.users).insert(
        UsersCompanion.insert(
          username: 'test_user',
          passwordHash: 'hashed_pw',
          displayName: 'Test User',
          createdAt: Value(now),
        ),
      );

      final categoryId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'Food',
          type: 'expense',
          iconCodepoint: Value(0xe5ca),
          userId: userId,
        ),
      );
      
      // 2.5 Create Account
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          name: 'Cash',
          balance: 0,
          currency: 'VND',
          userId: userId,
        ),
      );

      // 3. Create Budget (Limit 1,000,000)
      final budgetId = await db.into(db.budgets).insert(
        BudgetsCompanion.insert(
          categoryId: categoryId,
          amountLimit: 1000000,
          month: now.month,
          year: now.year,
          userId: Value(userId),
        ),
      );

      // 4. Create Expenses (Total 950,000 -> 95%)
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: 500000,
          type: 'expense',
          date: now,
          categoryId: Value(categoryId),
          userId: userId,
          accountId: accountId, 
        ),
      );
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: 450000,
          type: 'expense',
          date: now,
          categoryId: Value(categoryId),
          userId: userId,
          accountId: accountId,
        ),
      );

      // Act
      final alerts = await service.checkBudgets(userId);

      // Assert
      expect(alerts.length, 1);
      expect(alerts.first.categoryName, 'Food');
      expect(alerts.first.usagePercent, 95.0);
      expect(alerts.first.isOverBudget, false); // 95% < 100%

      // Verify notification called
      verify(() => mockNotificationService.showInstant(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      )).called(1);
    });

    test('Should NOT trigger alert when spending < 90%', () async {
      final now = DateTime.now();
      // Setup similar to above but less spending (500k / 1M = 50%)
       final userId = await db.into(db.users).insert(
        UsersCompanion.insert(
          username: 'user2', 
          passwordHash: 'pw', 
          displayName: 'User 2',
          createdAt: Value(now)
        ),
      );
      final categoryId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'Transport', 
          type: 'expense', 
          iconCodepoint: Value(0xe530),
          userId: userId,
        ),
      );
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          name: 'Cash',
          balance: 0,
          currency: 'VND',
          userId: userId,
        ),
      );
      await db.into(db.budgets).insert(
        BudgetsCompanion.insert(
          categoryId: categoryId,
          amountLimit: 1000000,
          month: now.month,
          year: now.year,
          userId: Value(userId),
        ),
      );
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: 500000,
          type: 'expense',
          date: now,
          categoryId: Value(categoryId),
          userId: userId,
          accountId: accountId,
        ),
      );

      // Act
      final alerts = await service.checkBudgets(userId);

      // Assert
      expect(alerts, isEmpty);
      verifyNever(() => mockNotificationService.showInstant(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ));
    });
  });
}
