import 'package:drift/drift.dart';
import 'dart:convert';

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
  /// 3. If [sourceAccountId] is provided, creating a Transfer Transaction
  ///    from Source Account -> Saving Account.
  ///    If null (initial balance mode), set balance directly without transfer.
  Future<void> createSaving({
    required String name,
    required double amount,
    required int termMonths,
    required double interestRate,
    required DateTime startDate,
    int? sourceAccountId, // null = initial balance (record only, no transfer)
    required int userId,
  }) async {
    await _db.transaction(() async {
      // 1. Create Saving Account
      // If no source account, set balance directly (initial balance / pre-existing saving)
      final isInitialBalance = sourceAccountId == null;
      final accountId = await _accountRepo.createAccount(
        AccountsCompanion(
          name: Value(name),
          balance: Value(isInitialBalance ? amount : 0),
          type: Value('SAVING_DEPOSIT'),
          userId: Value(userId),
        ),
      );

      // 2. Calculate details
      final maturityDate = DateTime(startDate.year, startDate.month + termMonths, startDate.day);
      final expectedInterest = amount * (interestRate / 100) * (termMonths / 12);

      // 3. Create Saving Record
      final savingId = await _db.into(_db.savings).insert(SavingsCompanion(
        accountId: Value(accountId),
        termMonths: Value(termMonths),
        interestRate: Value(interestRate),
        startDate: Value(startDate),
        maturityDate: Value(maturityDate),
        expectedInterest: Value(expectedInterest),
        status: Value('ACTIVE'),
      ));

      // 4. Transfer Money from Source -> Saving Account (only if source provided)
      if (!isInitialBalance) {
        await _transactionRepo.insertTransaction(
          TransactionsCompanion(
            amount: Value(amount),
            date: Value(startDate),
            type: Value('transfer'),
            note: Value('Savings deposit: $name'),
            accountId: Value(sourceAccountId),
            toAccountId: Value(accountId),
            userId: Value(userId),
          ),
        );
      }

      // 5. Audit log
      await _logChange(
        entityType: 'Saving',
        entityId: savingId,
        action: 'CREATE',
        newValue: {
          'id': savingId,
          'name': name,
          'amount': amount,
          'termMonths': termMonths,
          'interestRate': interestRate,
          'startDate': startDate.toIso8601String(),
          'maturityDate': maturityDate.toIso8601String(),
          'expectedInterest': expectedInterest,
          'sourceAccountId': sourceAccountId,
          'accountId': accountId,
          'isInitialBalance': isInitialBalance,
        },
        description: 'New saving: $name, amount: $amount, term: ${termMonths}m, initialBalance: $isInitialBalance',
      );
    });
  }

  /// Get saving by ID with account
  Future<SavingWithAccount?> getSavingById(int savingId) async {
    final query = _db.select(_db.savings).join([
      innerJoin(_db.accounts, _db.accounts.id.equalsExp(_db.savings.accountId)),
    ])
    ..where(_db.savings.id.equals(savingId));

    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return SavingWithAccount(
      saving: row.readTable(_db.savings),
      account: row.readTable(_db.accounts),
    );
  }

  /// Watch all savings (including SETTLED)
  Stream<List<SavingWithAccount>> watchAllSavings() {
    final query = _db.select(_db.savings).join([
      innerJoin(_db.accounts, _db.accounts.id.equalsExp(_db.savings.accountId)),
    ])
    ..orderBy([OrderingTerm.desc(_db.savings.startDate)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return SavingWithAccount(
          saving: row.readTable(_db.savings),
          account: row.readTable(_db.accounts),
        );
      }).toList();
    });
  }

  /// Update saving details (name, interest rate, term, start date)
  Future<void> updateSaving({
    required int savingId,
    String? name,
    double? amount, // V6: allow updating principal amount
    double? interestRate,
    int? termMonths,
    DateTime? startDate,
  }) async {
    await _db.transaction(() async {
      final saving = await (_db.select(_db.savings)..where((t) => t.id.equals(savingId))).getSingle();
      final oldAccount = await (_db.select(_db.accounts)..where((a) => a.id.equals(saving.accountId))).getSingle();

      // Capture old values for audit
      final oldValues = {
        'name': oldAccount.name,
        'interestRate': saving.interestRate,
        'termMonths': saving.termMonths,
        'startDate': saving.startDate.toIso8601String(),
      };

      // Update name on the linked account
      if (name != null) {
        await (_db.update(_db.accounts)..where((a) => a.id.equals(saving.accountId))).write(
          AccountsCompanion(name: Value(name)),
        );
      }

      // V6: Update principal amount logic
      if (amount != null && amount != oldAccount.balance) {
        final diff = amount - oldAccount.balance;

        // 1. Update Saving Account Balance
        await _accountRepo.updateBalance(saving.accountId, diff);

        // 2. Find associated transfer transaction (Source -> Saving Account)
        // We look for a transfer where toAccountId == saving.accountId
        // This assumes only ONE initial deposit transfer exists.
        final transferTx = await (_db.select(_db.transactions)
              ..where((t) =>
                  t.toAccountId.equals(saving.accountId) &
                  t.type.equals('transfer'))
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get().then((res) => res.firstOrNull);

        if (transferTx != null) {
          // 3. Update Transaction Amount
          await (_db.update(_db.transactions)..where((t) => t.id.equals(transferTx.id))).write(
            TransactionsCompanion(amount: Value(amount)),
          );

          // 4. Update Source Account Balance (Source balance decreases if amount increases)
          // Source Account ID is in transferTx.accountId
          if (transferTx.accountId != null) {
            await _accountRepo.updateBalance(transferTx.accountId!, -diff);
          }
        }
      }

      // Build savings update companion
      final updates = SavingsCompanion(
        interestRate: interestRate != null ? Value(interestRate) : const Value.absent(),
        termMonths: termMonths != null ? Value(termMonths) : const Value.absent(),
        startDate: startDate != null ? Value(startDate) : const Value.absent(),
      );

      // Recalculate maturity date and expected interest if term, rate, start date, OR AMOUNT changed
      if (termMonths != null || interestRate != null || startDate != null || amount != null) {
        final newTerm = termMonths ?? saving.termMonths;
        final newRate = interestRate ?? saving.interestRate;
        final newStart = startDate ?? saving.startDate;
        final newAmount = amount ?? oldAccount.balance; // Use new amount if set

        final maturityDate = DateTime(newStart.year, newStart.month + newTerm, newStart.day);
        
        // Simple Interest Formula: Principal * Rate * Time / 100
        final expectedInterest = newAmount * (newRate / 100) * (newTerm / 12);

        await (_db.update(_db.savings)..where((t) => t.id.equals(savingId))).write(
          SavingsCompanion(
            interestRate: Value(newRate),
            termMonths: Value(newTerm),
            startDate: startDate != null ? Value(newStart) : const Value.absent(),
            maturityDate: Value(maturityDate),
            expectedInterest: Value(expectedInterest),
          ),
        );
      } else {
        await (_db.update(_db.savings)..where((t) => t.id.equals(savingId))).write(updates);
      }

      // Audit log
      await _logChange(
        entityType: 'Saving',
        entityId: savingId,
        action: 'UPDATE',
        oldValue: oldValues,
        newValue: {
          if (name != null) 'name': name,
          if (amount != null) 'amount': amount,
          if (interestRate != null) 'interestRate': interestRate,
          if (termMonths != null) 'termMonths': termMonths,
          if (startDate != null) 'startDate': startDate.toIso8601String(),
        },
        description: 'Updated saving #$savingId (amount: ${amount ?? "unchanged"})',
      );
    });
  }

  /// Delete a saving and its related account + transactions
  Future<void> deleteSaving(int savingId) async {
    await _db.transaction(() async {
      final saving = await (_db.select(_db.savings)..where((t) => t.id.equals(savingId))).getSingle();
      final accountId = saving.accountId;
      final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(accountId))).getSingleOrNull();

      // Delete related transactions
      await (_db.delete(_db.transactions)..where((t) => t.accountId.equals(accountId))).go();
      await (_db.delete(_db.transactions)..where((t) => t.toAccountId.equals(accountId))).go();

      // Delete saving record
      await (_db.delete(_db.savings)..where((t) => t.id.equals(savingId))).go();

      // Delete linked account
      await (_db.delete(_db.accounts)..where((a) => a.id.equals(accountId))).go();

      // Audit log
      await _logChange(
        entityType: 'Saving',
        entityId: savingId,
        action: 'DELETE',
        oldValue: {
          'name': account?.name,
          'balance': account?.balance,
          'interestRate': saving.interestRate,
          'termMonths': saving.termMonths,
          'status': saving.status,
        },
        description: 'Deleted saving: ${account?.name}',
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
          note: Value('Savings settlement (principal): ${savingAccount.name}'),
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
            note: Value('Savings interest: ${savingAccount.name}'),
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

      // 5. Audit log
      await _logChange(
        entityType: 'Saving',
        entityId: savingId,
        action: 'SETTLE',
        oldValue: {
          'status': 'ACTIVE',
          'principal': principal,
          'expectedInterest': savingRow.expectedInterest,
        },
        newValue: {
          'status': 'SETTLED',
          'actualInterest': actualInterest,
          'targetAccountId': targetAccountId,
          'settleDate': settleDate.toIso8601String(),
        },
        description: 'Settled saving: ${savingAccount.name}, principal: $principal, interest: $actualInterest',
      );
    });
  }

  // -- Audit Log Helpers --

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

class SavingWithAccount {
  final Saving saving;
  final Account account;

  SavingWithAccount({required this.saving, required this.account});
}
