import 'package:drift/drift.dart';
import 'dart:convert';

import '../database/app_database.dart';

/// Repository for Account operations
class AccountRepository {
  final AppDatabase _db;

  AccountRepository(this._db);

  /// Get all active accounts for user
  Future<List<Account>> getAllAccounts(int userId) async {
    return (_db.select(_db.accounts)
          ..where((a) => a.userId.equals(userId) & a.isArchived.equals(false))
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .get();
  }

  /// Watch all active accounts for user
  Stream<List<Account>> watchAllAccounts(int userId) {
    return (_db.select(_db.accounts)
          ..where((a) => a.userId.equals(userId) & a.isArchived.equals(false))
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .watch();
  }

  /// Watch total balance for user
  Stream<double> watchTotalBalance(int userId) {
    return watchAllAccounts(userId).map(
      (accounts) => accounts.fold<double>(0, (sum, a) => sum + a.balance),
    );
  }

  /// Get account by ID (Generic)
  Future<Account?> getAccountById(int id) async {
    return (_db.select(_db.accounts)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert new account
  Future<int> insertAccount(AccountsCompanion account) async {
    final id = await _db.into(_db.accounts).insert(account);

    await _logChange(
      entityType: 'Account',
      entityId: id,
      action: 'CREATE',
      newValue: _companionToMap(account)..['id'] = id,
      description: 'New account: ${account.name.value}',
    );

    return id;
  }
  
  /// Alias for insertAccount
  Future<int> createAccount(AccountsCompanion account) => insertAccount(account);

  /// Update existing account
  Future<bool> updateAccount(Account account) async {
    final oldAccount = await getAccountById(account.id);

    final result = await _db.update(_db.accounts).replace(account.copyWith(
          updatedAt: Value(DateTime.now()),
        ));

    if (result) {
      await _logChange(
        entityType: 'Account',
        entityId: account.id,
        action: 'UPDATE',
        oldValue: oldAccount != null ? _accountToMap(oldAccount) : null,
        newValue: _accountToMap(account),
        description: 'Updated account: ${account.name}',
      );
    }

    return result;
  }
  
  /// Update account with companion
  Future<int> updateAccountCompanion(AccountsCompanion account) async {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(account.id.value))).write(account);
  }

  /// Update account balance by delta
  Future<void> updateBalance(int accountId, double delta) async {
    final account = await getAccountById(accountId);
    if (account != null) {
      await (_db.update(_db.accounts)..where((a) => a.id.equals(accountId)))
          .write(AccountsCompanion(
        balance: Value(account.balance + delta),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

   /// Archive account
  Future<void> archiveAccount(int accountId) async {
    final oldAccount = await getAccountById(accountId);

    await (_db.update(_db.accounts)..where((a) => a.id.equals(accountId)))
        .write(const AccountsCompanion(
      isArchived: Value(true),
      updatedAt: Value(null),
    ));

    await _logChange(
      entityType: 'Account',
      entityId: accountId,
      action: 'ARCHIVE',
      oldValue: oldAccount != null ? {'isArchived': false} : null,
      newValue: {'isArchived': true},
      description: 'Archived account: ${oldAccount?.name}',
    );
  }

  /// Delete account
  Future<int> deleteAccount(int accountId) async {
    final oldAccount = await getAccountById(accountId);
    final rows = await (_db.delete(_db.accounts)..where((a) => a.id.equals(accountId)))
        .go();

    if (rows > 0) {
      await _logChange(
        entityType: 'Account',
        entityId: accountId,
        action: 'DELETE',
        oldValue: oldAccount != null ? _accountToMap(oldAccount) : null,
        description: 'Deleted account: ${oldAccount?.name}',
      );
    }

    return rows;
  }

  // -- Audit Log Helpers --

  Map<String, dynamic> _accountToMap(Account row) {
    return {
      'id': row.id,
      'name': row.name,
      'balance': row.balance,
      'type': row.type,
      'isArchived': row.isArchived,
      'userId': row.userId,
    };
  }

  Map<String, dynamic> _companionToMap(AccountsCompanion c) {
    return {
      if (c.name.present) 'name': c.name.value,
      if (c.balance.present) 'balance': c.balance.value,
      if (c.type.present) 'type': c.type.value,
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
