# Release Notes - Thu Chi App

## v1.0.1+3 (Current)
**Released:** 2026-02-07
- Fix `file_picker` plugin warnings on Linux/Mac/Windows.
- Increment version to ensure clean install.

## v1.0.1+2 (Skipped/Internal)
**Released:** 2026-02-07

### 🐛 Bug Fixes
- Sửa lỗi hiển thị tiền tệ (CurrencyUtils) không đúng format VND (Rounding issue).
- Sửa lỗi logic database (Foreign key constraints) trong các module BudgetAlert và EventRepository.
- Fix unit tests: Toàn bộ suite test đã vượt qua kiểm tra.

### ✨ New Features
- **App Lock**: Tính năng bảo mật sinh trắc học và mã PIN được tích hợp. Tự động khóa sau 30 giây không hoạt động.
- **Release Build Stability**: Script build tự động cho cả Android và Linux.

---

## v1.0.0+1
**Released:** 2026-02-06
- Initial Release containing Core MVP features: Transactions, Categories, Budgets.
