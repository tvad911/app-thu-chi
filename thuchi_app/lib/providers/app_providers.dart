import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

import '../data/database/app_database.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/debt_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/audit_log_repository.dart';
import '../data/repositories/saving_repository.dart';
import '../data/repositories/bill_repository.dart';
import '../data/repositories/attachment_repository.dart';
import '../data/repositories/event_repository.dart';
import '../core/services/file_storage_service.dart';

/// Provider for the database instance
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provider for AccountRepository
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AccountRepository(db);
});

/// Provider for CategoryRepository
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryRepository(db);
});

/// Provider for TransactionRepository
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final accountRepo = ref.watch(accountRepositoryProvider);
  return TransactionRepository(db, accountRepo);
});

/// Provider for DebtRepository
final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final accountRepo = ref.watch(accountRepositoryProvider);
  return DebtRepository(db, accountRepo);
});

/// Provider for UserRepository
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return UserRepository(db);
});

/// Provider for BudgetRepository
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BudgetRepository(db);
});

/// Provider for AuditLogRepository
final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AuditLogRepository(db);
});

/// Provider for SavingRepository
final savingRepositoryProvider = Provider<SavingRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final accountRepo = ref.watch(accountRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  return SavingRepository(db, accountRepo, transactionRepo);
});

/// Provider for BillRepository
final billRepositoryProvider = Provider<BillRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BillRepository(db);
});

/// Provider for AttachmentRepository
final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AttachmentRepository(db);
});

/// Provider for FileStorageService
final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  return FileStorageService();
});

// ============================================================================
// Stream Providers for reactive data
// ============================================================================

/// Watch all accounts
final accountsProvider = StreamProvider<List<Account>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(accountRepositoryProvider);
  return repo.watchAllAccounts(user.id);
});

/// Watch total balance
final totalBalanceProvider = StreamProvider<double>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(accountRepositoryProvider);
  return repo.watchTotalBalance(user.id);
});

/// Watch spendable balance (excluding SAVING_DEPOSIT)
final spendableBalanceProvider = StreamProvider<double>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(accountRepositoryProvider);
  return repo.watchAllAccounts(user.id).map(
    (accounts) => accounts
        .where((a) => !['SAVING_DEPOSIT', 'saving_goal'].contains(a.type))
        .fold<double>(0, (sum, a) => sum + a.balance),
  );
});

/// Watch all categories
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.watchAllCategories(user.id);
});

/// Watch expense categories only
final expenseCategoriesProvider = StreamProvider<List<Category>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.watchCategoriesByType(user.id, 'expense');
});

/// Watch income categories only
final incomeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.watchCategoriesByType(user.id, 'income');
});

/// Watch recent transactions
final recentTransactionsProvider =
    StreamProvider<List<TransactionWithDetails>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchRecentTransactions(user.id, 20);
});

/// Watch active debts
final activeDebtsProvider = StreamProvider<List<Debt>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(debtRepositoryProvider);
  return repo.watchActiveDebts(user.id);
});

/// Watch budgets for a specific month
final budgetsForMonthProvider = StreamProvider.family<List<BudgetWithCategory>, (int, int)>((ref, args) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final (month, year) = args;
  final repo = ref.watch(budgetRepositoryProvider);
  return repo.watchBudgetsWithUsage(user.id, month, year);
});

/// Get monthly category stats
final monthlyCategoryStatsProvider = FutureProvider.family<List<CategoryStat>, (DateTime, String)>((ref, args) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final (month, type) = args;
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getCategoryStats(user.id, month, type);
});

/// Watch recent audit logs
final recentAuditLogsProvider = StreamProvider<List<AuditLog>>((ref) {
  final repo = ref.watch(auditLogRepositoryProvider);
  return repo.watchRecentLogs(50);
});

/// Watch active savings
final activeSavingsProvider = StreamProvider<List<SavingWithAccount>>((ref) {
  final repo = ref.watch(savingRepositoryProvider);
  return repo.watchActiveSavings();
});

/// Provider for EventRepository
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return EventRepository(db);
});

/// Watch active events
final activeEventsProvider = StreamProvider<List<Event>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.watch(eventRepositoryProvider);
  return repo.watchActiveEvents(user.id);
});
