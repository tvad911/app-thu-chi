# Đặc tả Ứng dụng Quản lý Thu Chi (specs.md)

> **Phiên bản:** 1.0.18  
> **Cập nhật:** 08/03/2026  
> **Công nghệ:** Flutter (Dart), Riverpod, Drift (SQLite)  
> **Nền tảng:** Android, Linux Desktop  
> **Chiến lược:** Offline-first, Hybrid Cloud Sync

---

## 1. Tổng quan

Ứng dụng quản lý tài chính cá nhân tập trung vào:
- **Tốc độ nhập liệu** (trong 3 giây)
- **Kiểm soát dòng tiền** theo phân loại (cố định / không cố định)
- **Bảo mật** (PIN + sinh trắc học)
- **Offline-first** — dữ liệu lưu SQLite cục bộ, sao lưu qua JSON/Google Drive/S3

### Stakeholders
- **Người dùng:** Nhập nhanh, giao diện gọn
- **Quản lý:** Nhìn thấy dòng tiền, chi phí cố định vs linh hoạt
- **Lập trình viên:** Kiến trúc DRY/SOLID, dễ port đa nền tảng

---

## 2. Kiến trúc kỹ thuật

### Tech Stack
| Thành phần | Công nghệ |
|---|---|
| Framework | Flutter (Stable) |
| State Management | Riverpod |
| Database | SQLite via `drift` (type-safe) |
| Backup | JSON export/import |
| Cloud Sync | Google Drive API, S3 (Minio) |
| Notification | `flutter_local_notifications` + `workmanager` |
| UI | Material Design 3, Google Fonts |
| Security | `flutter_secure_storage`, `local_auth` |

### Luồng dữ liệu
1. User nhập liệu → UI
2. Repository Layer → validate + business logic
3. Database Layer → SQLite (`app_data.db`)
4. Backup → Query DB → JSON → Lưu/Sync

---

## 3. Các module chức năng

### 3.1. Quản lý Ví (Accounts)

- **Loại ví:** `CASH`, `BANK`, `CREDIT`, `SAVING`, `SAVING_GOAL`, `E_WALLET`
- Tổng tài sản = Σ(số dư các ví)
- Hỗ trợ **chuyển tiền (Transfer)** giữa ví — không tính thu/chi
- **Cho phép ví âm** — bổ sung tiền sau
- Ví điện tử: Momo, ZaloPay, ShopeePay, ViettelMoney
- Nhấn vào ví → xem lịch sử giao dịch

### 3.2. Quản lý Giao dịch (Core)

**Phân loại:**
- **Income (Thu):** Lương, Thưởng, Lãi tiết kiệm
- **Expense (Chi):** Ăn uống, Thuê nhà
- **Transfer (Chuyển khoản):** Giữa các ví, ATM

**Đặc tính chi phí (Expense Nature):**
- **Fixed (Cố định):** Bắt buộc — tiền nhà, trả góp, học phí
- **Variable (Không cố định):** Linh hoạt — cafe, mua sắm → nơi cắt giảm

**UI giao dịch:**
- Viền icon: xanh lá (thu) / đỏ (chi)
- Icon màu theo category
- Nhóm giao dịch theo ngày

### 3.3. Quản lý Nợ (Debts)

- Ghi nợ: Tên người, Số tiền, Hạn trả
- Thanh toán: Trừ dần (Partial Payment), phân biệt Gốc vs Lãi
- Nhắc nhở: Notification trước hạn
- **Tùy chọn ghi nhận giao dịch:** Nợ cũ chỉ ghi sổ, không trừ ví

**Logic nghiệp vụ quan trọng:**

| Hành động | Loại | Tác động Ví | Báo cáo |
|---|---|---|---|
| Nhận tiền vay | Transfer In | +Ví | Không tính Thu |
| Trả nợ (gốc) | Transfer Out | -Ví | Không tính Chi |
| Trả nợ (lãi) | Expense | -Ví | **Tính** là Chi |
| Cho mượn | Transfer Out | -Ví | Không tính Chi |
| Thu nợ (gốc) | Transfer In | +Ví | Không tính Thu |
| Thu nợ (lãi) | Income | +Ví | **Tính** là Thu |

### 3.4. Tiết kiệm (Savings)

- Tạo sổ tiết kiệm: lãi suất, kỳ hạn, ngày bắt đầu
- **Ghi chú** cho khoản tiết kiệm
- **3 tùy chọn đáo hạn:**
  - Tất toán (lãi + vốn)
  - Tiếp tục gửi cùng kỳ hạn (lãi + vốn)
  - Tiếp tục gửi vốn + nhận lãi
- Gửi/rút = Transfer → không tính thu/chi
- Nhận lãi = Income
- Hỗ trợ **số dư ban đầu** (không cần trừ ví)
- Ví SAVING **ẩn** khỏi danh sách nguồn tiền hàng ngày

### 3.5. Ngân sách (Budgets)

- Hạn mức chi tiêu theo Category + tháng
- **Cảnh báo:**
  - `< 80%`: 🟢 Xanh
  - `80–99%`: 🟡 Vàng
  - `≥ 100%`: 🔴 Đỏ
- Progress bar với màu sắc category
- Chi tiết ngân sách: giao dịch viền xanh/đỏ giống thu chi thông thường
- Tự động lặp lại tháng sau (tùy chọn)

### 3.6. Sự kiện (Events / Travel Mode)

- **Mục đích:** Tách chi tiêu dịp đặc biệt (du lịch, tiệc) khỏi sinh hoạt hàng tháng
- Tạo sự kiện: Tên, Ngày bắt đầu–kết thúc, Ngân sách
- Gán giao dịch vào sự kiện (tag `event_id`)
- Dashboard riêng cho từng sự kiện
- **Toggle "Không bao gồm Sự kiện"** khi xem báo cáo tháng

### 3.7. Hóa đơn đinh kỳ (Bills)

- Chu kỳ: Hàng tháng, tuần, năm
- Trạng thái: Chờ thanh toán, Đã trả, Quá hạn
- Khi thanh toán → tự động tạo Transaction (Expense) + sinh bill kỳ sau
- Nhắc nhở trước ngày đến hạn

### 3.8. Quỹ Tích lũy (Financial Goals)

- Coi quỹ là Account đặc biệt (`SAVING_GOAL`)
- Chuyển tiền từ ví chính → ví quỹ = Transfer
- Tiến độ: % đạt mục tiêu
- Tiền trong quỹ ẩn khỏi chi tiêu hàng ngày

### 3.9. Báo cáo & Thống kê (Reports)

- **Dashboard:** Số dư, biểu đồ cột thu/chi tháng
- **Pie Chart:** Tỷ lệ Fixed vs Variable
- **Bar Chart:** Thu/chi theo ngày
- **Bộ lọc nâng cao:**
  - Lọc theo loại (thu/chi/CK)
  - Lọc theo danh mục (phân nhóm thu/chi)
  - Lọc theo ví
  - Lọc theo khoảng ngày
- Tab giao dịch theo tháng
- Toggle loại bỏ sự kiện

### 3.10. Bảo mật

- **PIN 4–6 số** + sinh trắc học (vân tay / FaceID)
- Tự động khóa khi app background > 30 giây
- **Chế độ riêng tư:** Che số dư (`***`)
- Lưu PIN qua `flutter_secure_storage`

### 3.11. Sao lưu & Phục hồi

- **Snapshot:** Tạo bản sao lưu nhanh (nút xóa + khôi phục trên mỗi row)
- **Backup JSON:** Xuất toàn bộ DB → JSON → chia sẻ
- **Restore:** Import JSON → xóa/merge dữ liệu cũ
- **Cloud Sync:** Google Drive / S3 (Minio)
  - Upload ảnh đính kèm lên cloud
  - Lazy load: metadata trước, ảnh khi xem chi tiết

### 3.12. Tìm kiếm nâng cao (Advanced Search)

- Tìm theo từ khóa (note)
- Lọc theo khoảng tiền (min–max)
- Lọc theo danh mục, ví, người
- Lọc theo khoảng thời gian
- Hỗ trợ tiếng Việt không dấu

### 3.13. Đa tiền tệ (Multi-currency) — Tương lai

- Mỗi ví gắn loại tiền (VND, USD, EUR)
- Tỷ giá do user nhập tay hoặc gợi ý
- Dashboard quy đổi về đơn vị chính

### 3.14. Quét hóa đơn OCR — Tương lai

- Chụp ảnh → Google ML Kit → Trích xuất tổng tiền + ngày
- Điền tự động vào form

---

## 4. Cơ sở dữ liệu (Database Schema)

> Drift (SQLite), schema version 10

### accounts
| Cột | Kiểu | Mô tả |
|---|---|---|
| id | INTEGER PK | Auto increment |
| name | TEXT | Tên ví |
| balance | REAL | Số dư |
| type | TEXT | `CASH`, `BANK`, `CREDIT`, `SAVING`, `SAVING_GOAL`, `E_WALLET` |
| is_archived | BOOLEAN | Ẩn ví |

### categories
| Cột | Kiểu | Mô tả |
|---|---|---|
| id | INTEGER PK | |
| name | TEXT | Tên danh mục |
| type | TEXT | `INCOME`, `EXPENSE` |
| nature | TEXT | `FIXED`, `VARIABLE` |
| icon_codepoint | INTEGER | Mã icon Material |
| color | TEXT | Hex color (nullable) |

### transactions
| Cột | Kiểu | Mô tả |
|---|---|---|
| id | INTEGER PK | |
| amount | REAL | Số tiền |
| date | INTEGER | Unix timestamp |
| note | TEXT | Ghi chú |
| type | TEXT | `income`, `expense`, `transfer` |
| account_id | INTEGER FK | Ví nguồn |
| category_id | INTEGER FK | Danh mục |
| to_account_id | INTEGER FK | Ví đích (Transfer) |
| event_id | INTEGER FK | Sự kiện (nullable) |
| image_path | TEXT | Ảnh đính kèm |

### debts
| Cột | Kiểu | Mô tả |
|---|---|---|
| id | INTEGER PK | |
| person | TEXT | Tên người |
| total_amount | REAL | Tổng nợ gốc |
| paid_amount | REAL | Đã trả |
| due_date | INTEGER | Hạn trả |
| type | TEXT | `LEND`, `BORROW` |
| is_finished | BOOLEAN | Hoàn thành |

### budgets
| Cột | Kiểu | Mô tả |
|---|---|---|
| id | INTEGER PK | |
| category_id | INTEGER FK | Danh mục (EXPENSE) |
| amount_limit | REAL | Hạn mức |
| month | INTEGER | Tháng |
| year | INTEGER | Năm |
| is_recurring | BOOLEAN | Tự lặp lại |

### savings
| Cột | Kiểu | Mô tả |
|---|---|---|
| id | INTEGER PK | |
| name | TEXT | Tên sổ |
| amount | REAL | Số tiền gửi |
| interest_rate | REAL | Lãi suất (%/năm) |
| start_date | INTEGER | Ngày bắt đầu |
| term_months | INTEGER | Kỳ hạn (tháng) |
| account_id | INTEGER FK | Ví nguồn |
| note | TEXT | Ghi chú |
| maturity_action | TEXT | `SETTLE`, `RENEW_ALL`, `RENEW_PRINCIPAL` |

### events
| Cột | Kiểu | Mô tả |
|---|---|---|
| id | INTEGER PK | |
| name | TEXT | Tên sự kiện |
| start_date | INTEGER | Ngày bắt đầu |
| end_date | INTEGER | Ngày kết thúc |
| is_finished | BOOLEAN | Đã kết thúc |
| budget | REAL | Ngân sách dự kiến |

### bills
| Cột | Kiểu | Mô tả |
|---|---|---|
| id | INTEGER PK | |
| title | TEXT | Tên hóa đơn |
| amount | REAL | Số tiền |
| due_date | INTEGER | Ngày đến hạn |
| repeat_cycle | TEXT | `MONTHLY`, `WEEKLY`, `YEARLY` |
| notify_before | INTEGER | Nhắc trước (ngày) |
| category_id | INTEGER FK | Danh mục |

### attachments
| Cột | Kiểu | Mô tả |
|---|---|---|
| id | INTEGER PK | |
| transaction_id | INTEGER FK | Giao dịch (nullable) |
| debt_id | INTEGER FK | Nợ (nullable) |
| file_name | TEXT | Tên file |
| local_path | TEXT | Đường dẫn local |
| drive_file_id | TEXT | ID Google Drive (nullable) |
| sync_status | TEXT | `PENDING`, `SYNCED`, `ERROR` |

---

## 5. Logic dòng tiền (Cashflow)

### Tính số dư ví
```
Balance = Σ(Income) - Σ(Expense) + Σ(Transfer_In) - Σ(Transfer_Out)
```

### Tổng chi tiêu (báo cáo)
```
TotalExpense = Σ(Expense thường) + Σ(Lãi trả cho khoản vay)
```
**KHÔNG** bao gồm: trả gốc nợ, chuyển tiền tiết kiệm

### Tổng thu nhập (báo cáo)
```
TotalIncome = Σ(Income thường) + Σ(Lãi cho vay) + Σ(Lãi tiết kiệm)
```
**KHÔNG** bao gồm: tiền đi vay, thu hồi gốc nợ

---

## 6. Cấu trúc dự án

```
thuchi/
├── thuchi_app/              # Flutter source
│   ├── lib/
│   │   ├── core/            # Theme, Utils, Services
│   │   ├── data/            # Database, Repositories
│   │   ├── presentation/    # Screens, Widgets
│   │   └── providers/       # Riverpod providers
│   ├── assets/              # Icons, Fonts
│   └── pubspec.yaml
├── version.json             # Version + update URL
├── release.md               # Hướng dẫn build & phát hành
├── update.md                # Hướng dẫn cập nhật qua Git
└── specs.md                 # Tài liệu đặc tả (file này)
```

---

## 7. Ghi chú

- **Responsive:** `LayoutBuilder` cho đa màn hình (Mobile dọc / Desktop Master-Detail)
- **Ảnh:** Chỉ lưu đường dẫn local, không đưa vào JSON backup
- **Tìm kiếm tiếng Việt:** Lưu thêm `normalized_note` (không dấu, lowercase)
- **Keyboard (Linux):** Hỗ trợ Tab + Enter điều hướng form
- **Build APK:** Luôn dùng `--no-tree-shake-icons` (do IconData dynamic)
