/// Account type enumeration
enum AccountType {
  cash,
  bank,
  credit,
  saving_goal,
  eWallet;

  String get displayName {
    switch (this) {
      case AccountType.cash:
        return 'Tiền mặt';
      case AccountType.bank:
        return 'Ngân hàng';
      case AccountType.credit:
        return 'Thẻ tín dụng';
      case AccountType.saving_goal:
        return 'Quỹ tích lũy';
      case AccountType.eWallet:
        return 'Ví điện tử';
    }
  }
}

/// Category type enumeration
enum CategoryType {
  income,
  expense;

  String get displayName {
    switch (this) {
      case CategoryType.income:
        return 'Thu nhập';
      case CategoryType.expense:
        return 'Chi tiêu';
    }
  }
}

/// Expense nature - Key feature for fixed vs variable expenses
enum ExpenseNature {
  fixed,
  variable;

  String get displayName {
    switch (this) {
      case ExpenseNature.fixed:
        return 'Cố định';
      case ExpenseNature.variable:
        return 'Biến đổi';
    }
  }
}

/// Debt type enumeration
enum DebtType {
  lend,
  borrow;

  String get displayName {
    switch (this) {
      case DebtType.lend:
        return 'Cho vay';
      case DebtType.borrow:
        return 'Đi vay';
    }
  }
}

/// Transaction type enumeration
enum TransactionType {
  income,
  expense,
  transfer;

  String get displayName {
    switch (this) {
      case TransactionType.income:
        return 'Thu';
      case TransactionType.expense:
        return 'Chi';
      case TransactionType.transfer:
        return 'Chuyển khoản';
    }
  }
}

/// Interest type enumeration for debt calculations
enum InterestType {
  percentYear,
  percentMonth,
  fixed;

  String get displayName {
    switch (this) {
      case InterestType.percentYear:
        return '%/Năm';
      case InterestType.percentMonth:
        return '%/Tháng';
      case InterestType.fixed:
        return 'Cố định';
    }
  }
}

/// Repeat cycle for recurring bills
enum RepeatCycle {
  NONE,
  WEEKLY,
  MONTHLY,
  YEARLY;

  String get displayName {
    switch (this) {
      case RepeatCycle.NONE:
        return 'Không lặp';
      case RepeatCycle.WEEKLY:
        return 'Hàng tuần';
      case RepeatCycle.MONTHLY:
        return 'Hàng tháng';
      case RepeatCycle.YEARLY:
        return 'Hàng năm';
    }
  }
}
