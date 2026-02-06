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

  /// Create new debt with automatic transaction
  Future<int> createDebt(DebtsCompanion debt, int accountId) async {
    return _db.transaction(() async {
      // 1. Insert debt record
      final debtId = await _db.into(_db.debts).insert(debt);

      // 2. Create initial transaction
      final type = debt.type.value; // 'borrow' or 'lend'
      final amount = debt.totalAmount.value;
      
      // If BORROW -> We receive money (INCOME)
      // If LEND -> We give money (EXPENSE)
      final transType = type == 'borrow' ? 'income' : 'expense';
      
      await _db.into(_db.transactions).insert(TransactionsCompanion(
        amount: Value(amount),
        date: Value(debt.startDate.value),
        type: Value(transType),
        note: Value('Khoản ${type == "borrow" ? "vay" : "cho vay"}: ${debt.person.value}'),
        accountId: Value(accountId),
        debtId: Value(debtId),
        userId: debt.userId,
      ));

      // 3. Update account balance
      await _accountRepo.updateBalance(accountId, type == 'borrow' ? amount : -amount);

      return debtId;
    });
  }

  /// Update debt
  Future<bool> updateDebt(Debt debt) async {
    return _db.update(_db.debts).replace(debt.copyWith(
          updatedAt: Value(DateTime.now()),
        ));
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
        note: Value('${note ?? "Trả gốc"}: ${debt.person}'),
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
          note: Value('Tiền lãi: ${debt.person}'),
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
    });
  }

  /// Get transactions for a specific debt
  Future<List<Transaction>> getDebtTransactions(int debtId) async {
    return (_db.select(_db.transactions)
          ..where((t) => t.debtId.equals(debtId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }
}

