import 'package:drift/drift.dart';

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
    return _db.into(_db.accounts).insert(account);
  }
  
  /// Alias for insertAccount
  Future<int> createAccount(AccountsCompanion account) => insertAccount(account);

  /// Update existing account
  Future<bool> updateAccount(Account account) async {
    return _db.update(_db.accounts).replace(account.copyWith(
          updatedAt: Value(DateTime.now()),
        ));
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
    await (_db.update(_db.accounts)..where((a) => a.id.equals(accountId)))
        .write(const AccountsCompanion(
      isArchived: Value(true),
      updatedAt: Value(null),
    ));
  }

  /// Delete account
  Future<int> deleteAccount(int accountId) async {
    return (_db.delete(_db.accounts)..where((a) => a.id.equals(accountId)))
        .go();
  }
}
