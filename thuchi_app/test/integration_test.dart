import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuchi_app/data/database/app_database.dart';
import 'package:thuchi_app/data/repositories/account_repository.dart';
import 'package:thuchi_app/data/repositories/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late TransactionRepository transactionRepo;
  late int testUserId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepo = AccountRepository(db);
    transactionRepo = TransactionRepository(db, accountRepo);

    // Create a dummy user
    testUserId = await db.into(db.users).insert(UsersCompanion.insert(
      username: 'test_user',
      passwordHash: 'hash',
      displayName: 'Test User',
    ));
  });

  tearDown(() async {
    await db.close();
  });

  test('Insert transaction should update account balance', () async {
    // 1. Create a test account
    final accountId = await accountRepo.insertAccount(
      AccountsCompanion(
        name: const Value('Test Wallet'),
        balance: const Value(1000000), // 1.000.000 VND
        type: const Value('cash'),
        userId: Value(testUserId),
      ),
    );

    // 2. Insert an EXPENSE transaction
    await transactionRepo.insertTransaction(
      TransactionsCompanion(
        amount: const Value(200000), // 200.000 VND
        date: Value(DateTime.now()),
        type: const Value('expense'),
        accountId: Value(accountId),
        userId: Value(testUserId),
      ),
    );

    // 3. Verify balance decreased
    var account = await accountRepo.getAccountById(accountId);
    expect(account!.balance, 800000); // 1m - 200k = 800k

    // 4. Insert an INCOME transaction
    await transactionRepo.insertTransaction(
      TransactionsCompanion(
        amount: const Value(500000),
        date: Value(DateTime.now()),
        type: const Value('income'),
        accountId: Value(accountId),
        userId: Value(testUserId),
      ),
    );

    // 5. Verify balance increased
    account = await accountRepo.getAccountById(accountId);
    expect(account!.balance, 1300000); // 800k + 500k = 1.3m
  });

  test('Transfer transaction should update both accounts', () async {
    // 1. Create Source and Dest accounts
    final sourceId = await accountRepo.insertAccount(
      AccountsCompanion(
        name: const Value('Source'),
        balance: const Value(1000000),
        type: const Value('cash'),
        userId: Value(testUserId),
      ),
    );
    final destId = await accountRepo.insertAccount(
      AccountsCompanion(
        name: const Value('Dest'),
        balance: const Value(0),
        type: const Value('bank'),
        userId: Value(testUserId),
      ),
    );

    // 2. Perform Transfer
    await transactionRepo.insertTransaction(
      TransactionsCompanion(
        amount: const Value(300000),
        date: Value(DateTime.now()),
        type: const Value('transfer'),
        accountId: Value(sourceId),
        toAccountId: Value(destId),
        userId: Value(testUserId),
      ),
    );

    // 3. Verify balances
    final source = await accountRepo.getAccountById(sourceId);
    final dest = await accountRepo.getAccountById(destId);

    expect(source!.balance, 700000); // 1m - 300k
    expect(dest!.balance, 300000);   // 0 + 300k
  });
}
