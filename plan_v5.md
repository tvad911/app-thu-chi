# Plan V5 — Chức năng Sự kiện (Events)

## Khái niệm

Sự kiện giống như một **"Thẻ" (Tag)** kẹp vào giao dịch. Nó **không phải Ví** (không chứa tiền), cũng **không phải Danh mục** (không định nghĩa bản chất chi tiêu).

> **Sự kiện giúp giải quyết câu hỏi:** "Tháng này tiêu nhiều thế là do sinh hoạt phí tăng hay do đi chơi?"

| Khái niệm | Vai trò |
|---|---|
| **Ví tiền** | Quản lý tiền thực tế |
| **Danh mục** | Quản lý bản chất chi tiêu |
| **Sự kiện** | Quản lý bối cảnh chi tiêu (ngắn hạn) |

---

## 1. Kịch bản thực tế: Chuyến đi Đà Lạt

### Bước 1: Khởi tạo Sự kiện (Lên kế hoạch)

Nam vào tab **"Sự kiện"** → Tạo mới:

- **Tên:** Du lịch Đà Lạt
- **Thời gian:** 10/02 – 15/02
- **Ngân sách (Budget):** 5.000.000đ
- **Trạng thái:** Đang diễn ra (Running)

### Bước 2: Phát sinh chi tiêu (Gắn thẻ)

Nam đi ăn lẩu gà lá é hết 500k. Nam mở App → **Thêm Giao dịch**:

- **Số tiền:** 500.000đ
- **Ví:** Tiền mặt *(tiền trong ví giảm thật)*
- **Danh mục:** Ăn uống *(để biết là ăn chứ không phải ở)*
- **Sự kiện:** "Du lịch Đà Lạt" *(chọn thêm)*

> **Logic Code:** Trong bảng `transactions`, cột `event_id` lưu ID của sự kiện Đà Lạt. Cột `account_id` vẫn trừ tiền ví Tiền mặt bình thường.

### Bước 3: Theo dõi (Tracking)

Nam vào tab Sự kiện → Bấm vào "Du lịch Đà Lạt". App hiển thị **Dashboard riêng** cho sự kiện:

- **Đã chi:** 500k
- **Ngân sách:** 5.000.000đ
- **Còn lại:** 4.500.000đ
- Danh sách các giao dịch chỉ thuộc sự kiện này

### Bước 4: Kết thúc & Báo cáo (Reporting)

1. Nam bấm nút **"Kết thúc sự kiện"** (`is_finished = true`)
2. Khi xem Báo cáo tháng 2, Nam thấy biểu đồ chi tiêu vọt lên cao → bấm **"Lọc bỏ sự kiện"**
3. App ẩn đi 500k tiền lẩu gà → biểu đồ quay về mức chi tiêu sinh hoạt bình thường

> **Mục đích:** Giúp so sánh chi tiêu đời sống tháng này với tháng trước một cách công bằng, không bị méo mó bởi chuyến đi chơi.

---

## 2. Logic lập trình (Implementation)

### A. Khi Thêm Giao dịch — Gắn `event_id`

Màn hình Add Transaction cần thêm **Dropdown chọn Sự kiện**.

```dart
class Transaction {
  double amount;
  int categoryId;
  int accountId;
  int? eventId; // Có thể null nếu chi tiêu thường
}
```

### B. Khi Tính toán Số dư Sự kiện (Dashboard Event)

Query tổng tiền của riêng sự kiện để so sánh với ngân sách:

```sql
SELECT SUM(amount)
FROM transactions
WHERE event_id = 1 AND type = 'EXPENSE';
```

### C. Khi Xem Báo cáo Tổng (Main Report) — Quan trọng

Cần biến `bool excludeEvents` (mặc định `false`):

```dart
Future<double> getMonthlyExpense(bool excludeEvents) async {
  String query = "SELECT SUM(amount) FROM transactions WHERE type = 'EXPENSE'";

  // Nếu user muốn loại bỏ tiền đi chơi ra khỏi báo cáo
  if (excludeEvents) {
    query += " AND event_id IS NULL";
  }
}
```

---

## 3. Gợi ý UI/UX

- **Nút chọn nhanh:** Nếu đang có sự kiện diễn ra (trong thời gian start–end), App tự động gợi ý chọn sự kiện đó trong form thêm giao dịch.
- **Widget ngoài Dashboard:** Nếu có sự kiện đang chạy, ghim Card nhỏ ở trang chủ: _"Đà Lạt: Đã tiêu 2.5tr / 5tr"_.
- **Chế độ nhóm (Advanced):** Sự kiện là nơi lý tưởng để tính "Ai trả tiền gì, ai nợ ai" trong nhóm bạn đi chơi (tính năng tương lai).