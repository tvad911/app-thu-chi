import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'account_repository.dart';
import 'transaction_repository.dart';

class SavingRepository {
  final AppDatabase _db;
  final AccountRepository _accountRepo;
  final TransactionRepository _transactionRepo;

  SavingRepository(this._db, this._accountRepo, this._transactionRepo);

  /// Watch all active savings
  Stream<List<SavingWithAccount>> watchActiveSavings() {
    final query = _db.select(_db.savings).join([
      innerJoin(_db.accounts, _db.accounts.id.equalsExp(_db.savings.accountId)),
    ])
    ..where(_db.savings.status.equals('ACTIVE'))
    ..orderBy([OrderingTerm.asc(_db.savings.maturityDate)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return SavingWithAccount(
          saving: row.readTable(_db.savings),
          account: row.readTable(_db.accounts),
        );
      }).toList();
    });
  }

  /// Add a new saving deposit
  /// This involves:
  /// 1. Creating a special Account for this saving
  /// 2. Creating a Savings record
  /// 3. Creating a Transfer Transaction from Source Account -> Saving Account
  Future<void> createSaving({
    required String name,
    required double amount,
    required int termMonths,
    required double interestRate,
    required DateTime startDate,
    required int sourceAccountId,
    required int userId,
  }) async {
    await _db.transaction(() async {
      // 1. Create Saving Account
      final accountId = await _accountRepo.createAccount(
        AccountsCompanion(
          name: Value(name),
          balance: Value(0), // Will be updated by transaction
          type: Value('SAVING_DEPOSIT'),
          userId: Value(userId),
        ),
      );

      // 2. Calculate details
      final maturityDate = DateTime(startDate.year, startDate.month + termMonths, startDate.day);
      // Simple Interest Formula: Principal * Rate * Time / 100
      // Rate is annual %. Time is in years (months/12).
      final expectedInterest = amount * (interestRate / 100) * (termMonths / 12);

      // 3. Create Saving Record
      await _db.into(_db.savings).insert(SavingsCompanion(
        accountId: Value(accountId),
        termMonths: Value(termMonths),
        interestRate: Value(interestRate),
        startDate: Value(startDate),
        maturityDate: Value(maturityDate),
        expectedInterest: Value(expectedInterest),
        status: Value('ACTIVE'),
      ));

      // 4. Transfer Money from Source -> Saving Account
      await _transactionRepo.insertTransaction(
        TransactionsCompanion(
          amount: Value(amount),
          date: Value(startDate),
          type: Value('transfer'),
          note: Value('Gửi tiết kiệm: $name'),
          accountId: Value(sourceAccountId),
          toAccountId: Value(accountId),
          userId: Value(userId),
        ),
      );
    });
  }

  /// Settle (Tất toán) a saving
  Future<void> settleSaving({
    required int savingId,
    required int targetAccountId,
    required double actualInterest,
    required DateTime settleDate,
    required int userId,
  }) async {
    await _db.transaction(() async {
      final savingRow = await (_db.select(_db.savings)..where((t) => t.id.equals(savingId))).getSingle();
      final savingAccount = await _accountRepo.getAccountById(savingRow.accountId);

      if (savingAccount == null) throw Exception("Saving account not found");

      final principal = savingAccount.balance;

      // 1. Transfer Principal Back: Saving Account -> Target Account
      await _transactionRepo.insertTransaction(
        TransactionsCompanion(
          amount: Value(principal),
          date: Value(settleDate),
          type: Value('transfer'),
          note: Value('Tất toán gốc: ${savingAccount.name}'),
          accountId: Value(savingAccount.id),
          toAccountId: Value(targetAccountId),
          userId: Value(userId),
        ),
      );

      // 2. Record Interest Income: Target Account
      if (actualInterest > 0) {
        await _transactionRepo.insertTransaction(
          TransactionsCompanion(
            amount: Value(actualInterest),
            date: Value(settleDate),
            type: Value('income'),
            note: Value('Lãi tiết kiệm: ${savingAccount.name}'),
            accountId: Value(targetAccountId),
            // You might want a default category for Interest here
            userId: Value(userId),
          ),
        );
      }

      // 3. Mark Saving as SETTLED
      await (_db.update(_db.savings)..where((t) => t.id.equals(savingId))).write(
        const SavingsCompanion(status: Value('SETTLED')),
      );

      // 4. Archive the Saving Account so it doesn't clutter the list
      await _accountRepo.updateAccountCompanion(
        AccountsCompanion(
          id: Value(savingAccount.id),
          isArchived: Value(true),
        ),
      );
    });
  }
}

class SavingWithAccount {
  final Saving saving;
  final Account account;

  SavingWithAccount({required this.saving, required this.account});
}
