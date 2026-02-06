import 'package:drift/drift.dart';
import 'accounts_table.dart';

/// Table to store details of Term Deposits / Savings
class Savings extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  /// The account ID representing this saving deposit.
  /// The balance in this account is the Principal Amount (Tiền gốc).
  IntColumn get accountId => integer().references(Accounts, #id)();
  
  /// Term in months (e.g., 1, 3, 6, 12, 36)
  IntColumn get termMonths => integer()();
  
  /// Annual Interest Rate (e.g., 5.5 for 5.5%/year)
  RealColumn get interestRate => real()();
  
  /// Date when the deposit started
  DateTimeColumn get startDate => dateTime()();
  
  /// Date when the deposit matures (startDate + termMonths)
  DateTimeColumn get maturityDate => dateTime()();
  
  /// Expected interest amount at maturity
  RealColumn get expectedInterest => real()();
  
  /// Status: 'ACTIVE' (Đang gửi), 'SETTLED' (Đã tất toán)
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();
}
