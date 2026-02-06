# SPEC-001: Ứng dụng Quản lý Chi tiêu Đa nền tảng (Personal Finance Manager)

- **Phiên bản:** 1.0.0
- **Ngày tạo:** 05/02/2026
- **Tech Stack:** Flutter (Dart)
- **Target Platform:** Android, iOS, Linux Desktop

---

## 1. Tổng quan (Overview)

Ứng dụng quản lý tài chính cá nhân tập trung vào sự tối giản, tốc độ nhập liệu nhanh và khả năng kiểm soát dòng tiền dựa trên phân loại chi phí (Cố định/Không cố định). Ứng dụng hoạt động **offline-first**, dữ liệu lưu cục bộ và có cơ chế sao lưu thủ công.

### Các bên liên quan (Stakeholders)
- **User (Người dùng cuối):** Cần nhập liệu nhanh (trong 3 giây), giao diện không rối rắm.
- **Manager (Người quản lý):** Cần nhìn thấy dòng tiền, biết được bao nhiêu tiền đang "chết" (cố định) và bao nhiêu tiền có thể cắt giảm (không cố định).
- **Developer (Lập trình viên):** Cần code kiến trúc sạch, dễ bảo trì, dễ port sang OS khác.

---

## 2. Kiến trúc Kỹ thuật (Technical Architecture)

### 2.1. Công nghệ (Tech Stack)
- **Framework:** Flutter (Stable Channel).
- **Ngôn ngữ:** Dart.
- **State Management:** Riverpod (Đề xuất cho dự án mới).
- **Local Database:** `sqlite3` (Sử dụng thư viện `drift`).
    - *Lý do:* `drift` viết bằng Dart, type-safe, hỗ trợ tốt cho cả Mobile và Desktop Linux.
- **Backup/Restore:** Serialize dữ liệu ra file `.json`.
- **Notification:** `flutter_local_notifications` (Hỗ trợ Mobile & Linux).
- **UI Library:** Google Material Design 3.

### 2.2. Luồng dữ liệu (Data Flow)
1. User nhập liệu trên UI.
2. **Repository Layer** xử lý logic nghiệp vụ (Validate tiền, ngày tháng).
3. **Database Layer** lưu vào SQLite file (`app_data.db`).
4. **Backup Process:** Query toàn bộ DB -> Convert List Object sang JSON -> Ghi ra file `backup_YYYYMMDD.json`.

---

## 3. Đặc tả Chức năng (Functional Specifications)

### 3.1. Quản lý Tài khoản (Wallet/Accounts)
- **Mô tả:** Nơi chứa tiền (Tiền mặt, Ngân hàng, Thẻ tín dụng).
- **Logic:**
    - Tổng tài sản = Tổng số dư các ví cộng lại.
    - Hỗ trợ chuyển tiền (**Transfer**) giữa các ví (Không tính là Chi hay Thu).
- **Dữ liệu:** Tên ví, Loại ví, Số dư, Màu sắc nhận diện.

### 3.2. Quản lý Giao dịch (Core Feature)
- **Phân loại Giao dịch (Transaction Types):**
    - **Income (Thu):** Lương, Thưởng, Bán đồ.
    - **Expense (Chi):** Ăn uống, Thuê nhà.
    - **Transfer (Chuyển khoản):** Rút tiền ATM, Nạp thẻ.
- **Đặc tính Chi phí (Expense Nature) - Key Feature:**
    - **Fixed (Cố định):** Các khoản bắt buộc (Tiền nhà, Trả góp, Học phí). -> Cảnh báo nếu dòng tiền không đủ trả khoản này.
    - **Variable (Không cố định):** Các khoản linh hoạt (Cafe, Mua sắm). -> Đây là nơi User nhìn vào để cắt giảm.

### 3.3. Quản lý Nợ & Nhắc hẹn (Debts & Reminders)
- **Mô tả:** Theo dõi ai nợ mình, mình nợ ai.
- **Chức năng:**
    - **Ghi nợ:** Tên người, Số tiền, Ngày đáo hạn.
    - **Thanh toán:** Trừ dần số tiền nợ (Partial Payment).
    - **Nhắc nhở:** Thông báo trước ngày đáo hạn (Notification).

### 3.4. Hệ thống Báo cáo (Reports)
- **Dashboard:** Hiển thị số dư hiện tại, Biểu đồ cột thu/chi tháng này.
- **Phân tích:**
    - **Pie Chart:** Tỷ lệ Chi Cố định vs Chi Không cố định (Quan trọng).
    - **List History:** Xem lại log theo timeline.
    - **Audit Log (Lịch sử thay đổi):** Ghi lại các hành động Thêm/Sửa/Xóa giao dịch để đối chiếu khi cần thiết (Ví dụ: "Đã sửa số tiền từ 50k -> 60k").

### 3.6. Quản lý Ngân sách (Budgets)
- **Mục đích:** Giới hạn số tiền được phép tiêu cho một Danh mục (Category) trong tháng.
- **Logic:** So sánh Tổng chi thực tế vs Hạn mức cài đặt.
- **Trạng thái Cảnh báo:**
    - **< 80%:** Màu Xanh (An toàn).
    - **80% - 99%:** Màu Vàng (Cảnh báo: Sắp hết tiền).
    - **>= 100%:** Màu Đỏ (Vỡ kế hoạch - Overspent).
- **UI:** Thanh tiến trình (Linear Progress Indicator).

### 3.7. Quỹ Tích lũy (Financial Goals)
- **Mục đích:** Tích lũy tiền cho tương lai hoặc trường hợp khẩn cấp (Phương pháp 6 chiếc hũ).
- **Cơ chế:** Coi các "Quỹ" này là một loại Tài khoản (Account) đặc biệt (`SAVING_GOAL`).
- **Logic:**
    - Khi có lương, user chuyển tiền (Transfer) từ Ví chính sang Ví quỹ.
    - Tiền trong Ví quỹ sẽ **không hiện** trong danh sách nguồn tiền khi tiêu dùng hàng ngày (để tránh tiêu lầm).
    - Hiển thị tiến độ đạt được mục tiêu nếu có (Ví dụ: Quỹ mua xe 30tr, hiện có 15tr -> 50%).

### 3.5. Sao lưu & Phục hồi (Backup & Restore)
- **Backup:**
    - Người dùng nhấn nút "Sao lưu dữ liệu".
    - Ứng dụng xuất ra file JSON chứa toàn bộ Accounts, Categories, Transactions, Debts.
    - Chọn nơi lưu (Máy, Telegram, Drive, Zalo).
- **Restore:**
    - Chọn file JSON từ máy.
    - Ứng dụng parse JSON -> Xóa dữ liệu cũ (hoặc merge) -> Insert vào SQLite -> Reload App.

---

## 4. Thiết kế Cơ sở dữ liệu (Database Schema - SQLite)

Dưới đây là thiết kế bảng. Khi dùng Flutter `drift`, dữ liệu sẽ được định nghĩa bằng Dart class.

### Table: Accounts
| Field | Type | Note |
| :--- | :--- | :--- |
| `id` | INTEGER PK | Auto Increment |
| `name` | TEXT | Ví dụ: "Ví tiền mặt" |
| `balance` | REAL | Số dư hiện tại |
| `type` | TEXT | CASH, BANK, CREDIT, SAVING_GOAL |
| `is_archived`| BOOLEAN | 0: Active, 1: Ẩn đi |

### Table: Categories
| Field | Type | Note |
| :--- | :--- | :--- |
| `id` | INTEGER PK | |
| `name` | TEXT | "Ăn uống", "Tiền nhà" |
| `type` | TEXT | INCOME, EXPENSE |
| `nature` | TEXT | FIXED, VARIABLE |
| `icon_codepoint`| INTEGER | Mã icon để hiển thị |

### Table: Transactions
| Field | Type | Note |
| :--- | :--- | :--- |
| `id` | INTEGER PK | |
| `amount` | REAL | Số tiền |
| `date` | INTEGER | Unix Timestamp (ms) |
| `note` | TEXT | Ghi chú |
| `account_id` | INTEGER FK | Link tới Accounts |
| `category_id` | INTEGER FK | Link tới Categories |
| `to_account_id`| INTEGER FK | Chỉ dùng khi Transfer |
| `image_path` | TEXT | Đường dẫn ảnh local |

### Table: Debts
| Field | Type | Note |
| :--- | :--- | :--- |
| `id` | INTEGER PK | |
| `person` | TEXT | Tên người vay/chủ nợ |
| `total_amount` | REAL | Tổng nợ gốc |
| `paid_amount` | REAL | Đã trả bao nhiêu |
| `due_date` | INTEGER | Hạn trả |
| `type` | TEXT | LEND (Cho vay), BORROW (Đi vay) |
| `is_finished` | BOOLEAN | Trạng thái hoàn thành |

### Table: Budgets
| Field | Type | Note |
| :--- | :--- | :--- |
| `id` | INTEGER PK | |
| `category_id` | INTEGER FK | Link tới Categories (EXPENSE only) |
| `amount_limit` | REAL | Số tiền giới hạn |
| `month` | INTEGER | Tháng áp dụng |
| `year` | INTEGER | Năm áp dụng |
| `is_recurring` | BOOLEAN | Tự động lặp lại cho tháng sau |

---

## 5. Cấu trúc File JSON Backup (Mẫu)

Đây là định dạng JSON để thực hiện hàm Import/Export:

```json
{
  "version": 1,
  "exported_at": 1707123456789,
  "accounts": [
    {"id": 1, "name": "Tiền mặt", "balance": 5000000, "type": "CASH"}
  ],
  "categories": [
    {"id": 1, "name": "Tiền nhà", "type": "EXPENSE", "nature": "FIXED"}
  ],
  "transactions": [
    {
      "amount": 2000000,
      "date": 1707123000000,
      "category_id": 1,
      "account_id": 1,
      "note": "Tiền nhà tháng 2"
    }
  ]
}
```

---

## 6. Kế hoạch triển khai (Implementation Plan)

### Phase 1: Skeleton & Database (Tuần 1)
- Khởi tạo Flutter Project (Android, Linux).
- Cài đặt packages: `drift`, `path_provider`, `flutter_riverpod`.
- Định nghĩa Schema Database.
- Viết Repository CRUD cho Account và Transaction.

### Phase 2: UI Cơ bản & Logic Thu Chi (Tuần 2)
- Màn hình Home: Danh sách ví & Tổng số dư.
- Màn hình Thêm Giao dịch:
    - Nhập số tiền, chọn Category, chọn ngày.
    - Logic tự động cập nhật số dư ví khi lưu giao dịch.

### Phase 3: Báo cáo & Backup (Tuần 3)
- Tích hợp `fl_chart` cho biểu đồ tròn (Pie Chart).
- Lọc giao dịch theo tháng.
- Phát triển tính năng Backup & Restore (toJson/fromJson).
dung
### Phase 4: Tính năng Nợ & Linux Optimization (Tuần 4)
- Màn hình Quản lý nợ & Thông báo nhắc nợ.
- Tối ưu hóa cho Linux: Xử lý resize, hỗ trợ phím tắt (Enter/Tab).

### Phase 5: Ngân sách & Mục tiêu Khởi tạo (Tuần 5)
- Thêm bảng `Budgets` và update `Accounts`.
- UI Quản lý Ngân sách: List Category + Progress Bar.
- Logic Cảnh báo chi tiêu (Xanh - Vàng - Đỏ).
- UI Quỹ tích lũy (Saving Goals) và luồng Transfer đặc biệt.

---

## 7. Ghi chú cho Lập trình viên

- **Responsive:** Sử dụng `LayoutBuilder` hoặc `ResponsiveBreakpoints` để hỗ trợ đa màn hình.
    - *Mobile:* Giao diện dọc.
    - *Linux:* Giao diện Master-Detail (Menu bên trái, nội dung bên phải).
- **Lưu ảnh:** Ảnh hóa đơn chỉ lưu đường dẫn cục bộ (Local path). Không đưa ảnh vào file JSON backup để tránh nặng file.
- **Keyboard (Linux):** Đảm bảo hỗ trợ tốt việc điều hướng bằng phím Tab và phím Enter để xác nhận form.