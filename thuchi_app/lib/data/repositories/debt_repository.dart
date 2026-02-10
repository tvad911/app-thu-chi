import 'package:drift/drift.dart';
import 'dart:convert';

import '../database/app_database.dart';
import 'account_repository.dart';

/// Repository for Debt operations
class DebtRepository {
  final AppDatabase _db;
  final AccountRepository _accountRepo;

  DebtRepository(this._db, this._accountRepo);

  /// Get active debts for user
  Future<List<Debt>> getActiveDebts(int userId) async {
    return (_db.select(_db.debts)
          ..where((d) => d.userId.equals(userId) & d.isFinished.equals(false))
          ..orderBy([(d) => OrderingTerm.asc(d.dueDate)]))
        .get();
  }

  /// Watch active debts for user
  Stream<List<Debt>> watchActiveDebts(int userId) {
    return (_db.select(_db.debts)
          ..where((d) => d.userId.equals(userId) & d.isFinished.equals(false))
          ..orderBy([(d) => OrderingTerm.asc(d.dueDate)]))
        .watch();
  }

  /// Get debt by ID
  Future<Debt?> getDebtById(int id) async {
    return (_db.select(_db.debts)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
  }

  /// Create new debt with optional transaction
  /// If [createTransaction] is true (default), a transfer transaction is created
  /// and the wallet balance is updated. If false, only the debt record is created
  /// (useful for recording pre-existing debts).
  Future<int> createDebt(DebtsCompanion debt, {int? accountId, bool createTransaction = true}) async {
    return _db.transaction(() async {
      // 1. Always insert debt record
      final debtId = await _db.into(_db.debts).insert(debt);

      final type = debt.type.value; // 'borrow' or 'lend'
      final amount = debt.totalAmount.value;

      // 2. Only create transaction + update balance if requested
      if (createTransaction && accountId != null) {
        // Principal is TRANSFER (not income/expense) per plan_v4 business logic.
        // Borrow: money flows IN (Transfer In) but is NOT income (must repay).
        // Lend: money flows OUT (Transfer Out) but is NOT expense (will collect).
        await _db.into(_db.transactions).insert(TransactionsCompanion(
          amount: Value(amount),
          date: Value(debt.startDate.value),
          type: const Value('transfer'),
          note: Value('Debt (${type == "borrow" ? "borrow" : "lend"}): ${debt.person.value}'),
          accountId: Value(accountId),
          debtId: Value(debtId),
          userId: debt.userId,
        ));

        // Update account balance
        await _accountRepo.updateBalance(accountId, type == 'borrow' ? amount : -amount);
      }

      // 3. Audit log
      await _logChange(
        entityType: 'Debt',
        entityId: debtId,
        action: 'CREATE',
        newValue: _companionToMap(debt)..['id'] = debtId..['accountId'] = accountId..['createTransaction'] = createTransaction,
        description: 'New debt ($type): ${debt.person.value}, amount: $amount, withTransaction: $createTransaction',
      );

      return debtId;
    });
  }

  /// Update debt
  /// Update debt
  Future<bool> updateDebt(Debt debt) async {
    final oldDebt = await getDebtById(debt.id);
    if (oldDebt == null) return false;

    // V6: Logic to handle amount changes
    if (debt.totalAmount != oldDebt.totalAmount) {
      final diff = debt.totalAmount - oldDebt.totalAmount;
      
      // 1. Find the INITIAL transaction (creation)
      // Usually the first transfer transaction for this debt.
      final tx = await (_db.select(_db.transactions)
            ..where((t) =>
                t.debtId.equals(debt.id) &
                t.type.equals('transfer')))
          .getSingleOrNull(); // Use getSingleOrNull() or ordering?
          // If there are repayments, there might be multiple transfers.
          // The creation one is likely the one matching totalAmount or earliest date.
      
      // Better Query: Order by ID ASC (creation happens first)
      final transactions = await (_db.select(_db.transactions)
            ..where((t) =>
                t.debtId.equals(debt.id) &
                t.type.equals('transfer'))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

      if (transactions.isNotEmpty) {
        final initialTx = transactions.first;
        
        // 2. Update Transaction Amount
        await (_db.update(_db.transactions)..where((t) => t.id.equals(initialTx.id))).write(
          TransactionsCompanion(amount: Value(debt.totalAmount)),
        );

        // 3. Update Account Balance
        // If Borrow: Balance increases (positive flow). Diff > 0 -> Balance + Diff.
        // If Lend: Balance decreases (negative flow). Diff > 0 -> Balance - Diff.
        if (initialTx.accountId != null) {
          if (debt.type == 'borrow') {
             await _accountRepo.updateBalance(initialTx.accountId!, diff);
          } else {
             await _accountRepo.updateBalance(initialTx.accountId!, -diff);
          }
        }
      }
      
      // 4. Update Remaining Amount
      // Start with old remaining, add the difference.
      // E.g. Borrowed 100, paid 20, remaining 80.
      // Update Borrow to 150 (diff +50). New remaining = 80 + 50 = 130. Correct.
      final newRemaining = oldDebt.remainingAmount + diff;
      debt = debt.copyWith(remainingAmount: newRemaining);
    }

    final result = await _db.update(_db.debts).replace(debt.copyWith(
          updatedAt: Value(DateTime.now()),
        ));

    if (result) {
      await _logChange(
        entityType: 'Debt',
        entityId: debt.id,
        action: 'UPDATE',
        oldValue: oldDebt != null ? _debtToMap(oldDebt) : null,
        newValue: _debtToMap(debt),
        description: 'Updated debt: ${debt.person} (amount: ${debt.totalAmount})',
      );
    }

    return result;
  }

  /// Delete debt and related transactions
  Future<void> deleteDebt(int id) async {
    final oldDebt = await getDebtById(id);

    await _db.transaction(() async {
      await (_db.delete(_db.transactions)..where((t) => t.debtId.equals(id))).go();
      await (_db.delete(_db.debts)..where((d) => d.id.equals(id))).go();

      await _logChange(
        entityType: 'Debt',
        entityId: id,
        action: 'DELETE',
        oldValue: oldDebt != null ? _debtToMap(oldDebt) : null,
        description: 'Deleted debt: ${oldDebt?.person}',
      );
    });
  }

  /// Add repayment transaction
  Future<void> addRepayment({
    required int debtId,
    required double principal,
    double interest = 0,
    required int accountId,
    int? categoryId, // Category for interest expense/income
    String? note,
  }) async {
    final debt = await getDebtById(debtId);
    if (debt == null) return;

    return _db.transaction(() async {
      final now = DateTime.now();
      
      // 1. Create transaction for Principal
      // Principal repayment is treated as a transfer-like adjustment to debtId
      await _db.into(_db.transactions).insert(TransactionsCompanion(
        amount: Value(principal),
        date: Value(now),
        type: Value('transfer'), // Use transfer for principal
        note: Value('${note ?? "Principal repayment"}: ${debt.person}'),
        accountId: Value(accountId),
        debtId: Value(debtId),
        userId: Value(debt.userId),
      ));

      // 2. Create transaction for Interest (if any)
      if (interest > 0) {
        // Borrow: interest is EXPENSE, Lend: interest is INCOME
        final interestType = debt.type == 'borrow' ? 'expense' : 'income';
        await _db.into(_db.transactions).insert(TransactionsCompanion(
          amount: Value(interest),
          date: Value(now),
          type: Value(interestType),
          note: Value('Interest payment: ${debt.person}'),
          accountId: Value(accountId),
          categoryId: Value(categoryId),
          debtId: Value(debtId),
          userId: Value(debt.userId),
        ));
      }

      // 3. Update Debt remaining amount
      final newRemaining = debt.remainingAmount - principal;
      final isFinished = newRemaining <= 0;

      await (_db.update(_db.debts)..where((d) => d.id.equals(debtId))).write(
        DebtsCompanion(
          remainingAmount: Value(newRemaining),
          isFinished: Value(isFinished),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // 4. Update Account Balance (Total Outflow = Principal + Interest)
      // If we are borrowing, we PAY principal+interest -> balance decreases
      // If we are lending, we RECEIVE principal+interest -> balance increases
      final totalEffect = principal + interest;
      await _accountRepo.updateBalance(accountId, debt.type == 'borrow' ? -totalEffect : totalEffect);

      // 5. Audit log
      await _logChange(
        entityType: 'Debt',
        entityId: debtId,
        action: 'REPAYMENT',
        oldValue: {'remainingAmount': debt.remainingAmount, 'isFinished': debt.isFinished},
        newValue: {
          'principal': principal,
          'interest': interest,
          'remainingAmount': newRemaining,
          'isFinished': isFinished,
          'accountId': accountId,
        },
        description: 'Repayment for ${debt.person}: principal=$principal, interest=$interest',
      );
    });
  }

  /// Get transactions for a specific debt
  Future<List<Transaction>> getDebtTransactions(int debtId) async {
    return (_db.select(_db.transactions)
          ..where((t) => t.debtId.equals(debtId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  // -- Audit Log Helpers --

  Map<String, dynamic> _debtToMap(Debt row) {
    return {
      'id': row.id,
      'type': row.type,
      'person': row.person,
      'totalAmount': row.totalAmount,
      'remainingAmount': row.remainingAmount,
      'startDate': row.startDate.toIso8601String(),
      'dueDate': row.dueDate?.toIso8601String(),
      'isFinished': row.isFinished,
      'userId': row.userId,
    };
  }

  Map<String, dynamic> _companionToMap(DebtsCompanion c) {
    return {
      if (c.type.present) 'type': c.type.value,
      if (c.person.present) 'person': c.person.value,
      if (c.totalAmount.present) 'totalAmount': c.totalAmount.value,
      if (c.remainingAmount.present) 'remainingAmount': c.remainingAmount.value,
      if (c.startDate.present) 'startDate': c.startDate.value.toIso8601String(),
      if (c.dueDate.present) 'dueDate': c.dueDate.value?.toIso8601String(),
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
