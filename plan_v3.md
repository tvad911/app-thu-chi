# SPEC-003: Ứng dụng Quản lý Tài chính Cá nhân (Ultimate Edition)

> **Phiên bản:** 3.0  
> **Ngày cập nhật:** 07/02/2026  
> **Công nghệ:** Flutter (Dart)  
> **Nền tảng:** Android, iOS, Linux  
> **Chiến lược:** Offline-first, Hybrid Cloud (Drive Sync), High Security

---

## 1. Tổng quan & Triết lý Sản phẩm

Xây dựng một **"Trợ lý tài chính"** chứ không chỉ là sổ ghi chép. Ứng dụng tập trung vào tính bảo mật tuyệt đối, khả năng tùy biến cao cho các nhu cầu thực tế (Du lịch, Đa tiền tệ) và báo cáo thông minh.

---

## 2. Chi tiết Các Module Chức năng Mới & Nâng cấp

### 2.1. Bảo mật & Riêng tư (Security — BẮT BUỘC)

#### Khóa ứng dụng (App Lock)
- Thiết lập mã PIN 4–6 số.
- Tích hợp Sinh trắc học (Vân tay / FaceID) qua thư viện `local_auth`.
- **Logic:** Tự động khóa khi app xuống background quá 30 giây.

#### Chế độ Riêng tư (Privacy Mode)
- **Che số dư:** Bấm vào icon "Mắt" hoặc Lắc điện thoại → Toàn bộ số tiền hiển thị dạng `***`.
- Giúp user thoải mái mở app nơi đông người.

---

### 2.2. Sự kiện & Chuyến đi (Events / Travel Mode)

**Mục đích:** Tách biệt chi tiêu cho một dịp đặc biệt (VD: "Du lịch Thái Lan") khỏi báo cáo sinh hoạt phí hàng tháng.

**Chức năng:**
- Tạo Sự kiện: Tên, Ngày bắt đầu – Kết thúc, Ngân sách dự kiến cho chuyến đi.
- Gán Transaction vào Event.
- Báo cáo riêng: "Chuyến đi này tổng hết bao nhiêu?", "Ai trả tiền gì?" (Cơ bản).
- **Toggle:** Khi xem báo cáo tháng, có nút "Không bao gồm Sự kiện" để xem chi tiêu thực tế đời sống.

---

### 2.3. Ngân sách & Cảnh báo (Smart Budgets)

**Thiết lập:** Đặt hạn mức cho từng Category theo tháng (VD: Ăn uống 3tr/tháng).

**Cảnh báo (Visual Alert):**
- `< 80%`: 🟢 Xanh (An toàn)
- `80% – 99%`: 🟡 Vàng (Cảnh báo)
- `>= 100%`: 🔴 Đỏ (Vỡ kế hoạch)

**Notification:** Bắn thông báo khi chi tiêu vừa vượt quá 90% hạn mức.

---

### 2.4. Đa tiền tệ (Multi-currency)

**Cấu hình:** Mỗi Ví (Account) gắn với một loại tiền tệ gốc (VND, USD, EUR, XAU-Vàng).

**Giao dịch:**
- Hỗ trợ nhập liệu khác loại tiền ví (VD: Ví VND nhưng quẹt thẻ mua hàng $10).
- Tự động gợi ý tỷ giá (hoặc nhập tay).

**Quy đổi:** Màn hình Dashboard tổng hợp sẽ quy đổi tất cả về đơn vị tiền tệ chính (Base Currency) để hiển thị Tổng tài sản.

---

### 2.5. Tìm kiếm & Lọc (Advanced Search)

- Thanh tìm kiếm (Search Bar) ngay trang chủ.
- **Bộ lọc đa chiều:**
  - Theo từ khóa (Note, Title).
  - Theo khoảng tiền (Min – Max).
  - Theo Danh mục, Ví, hoặc Người (liên quan nợ).
  - Theo khoảng thời gian.

---

### 2.6. Báo cáo & Dự báo (Advanced Reports)

- **Sổ quỹ (Cashbook View):** Hiển thị dạng bảng (Table) dòng tiền vào/ra theo thứ tự thời gian (giống Excel kế toán).
- **Phân tích Xu hướng:** So sánh tháng này với tháng trước.
- **Dự báo (Forecast):** Dựa vào lịch sử 3 tháng gần nhất → Dự đoán tháng này sẽ tiêu hết bao nhiêu nếu giữ nguyên tốc độ chi tiêu.

---

### 2.7. Quét Hóa đơn OCR (Low Priority — Future)

- Tính năng thử nghiệm (Experimental).
- Chụp ảnh hóa đơn → Dùng Google ML Kit (Text Recognition) → Trích xuất "Tổng tiền" và "Ngày tháng" → Điền vào Form nhập liệu.

---

## 3. Cập nhật Thiết kế Cơ sở dữ liệu (Database Schema)

> Sử dụng `drift` (SQLite). Dưới đây là các bảng **Cần Thêm** hoặc **Cập Nhật**.

### 3.1. Bảng Mới: `events`

| Trường       | Kiểu       | Mô tả                           |
|:-------------|:-----------|:---------------------------------|
| id           | INTEGER PK |                                  |
| name         | TEXT       | Tên sự kiện                     |
| start_date   | INTEGER    |                                  |
| end_date     | INTEGER    |                                  |
| is_finished  | BOOLEAN    | Đã kết thúc chưa                |
| budget       | REAL       | Ngân sách dự kiến cho sự kiện   |

### 3.2. Bảng Mới: `budgets`

> ✅ Đã tồn tại — cần kiểm tra và bổ sung nếu thiếu.

| Trường      | Kiểu       | Mô tả                 |
|:------------|:-----------|:-----------------------|
| id          | INTEGER PK |                        |
| category_id | INTEGER FK | Danh mục áp dụng      |
| amount      | REAL       | Hạn mức (VD: 5,000,000) |
| month       | INTEGER    | Tháng áp dụng         |
| year        | INTEGER    | Năm áp dụng           |

### 3.3. Bảng Mới: `currencies` (Tùy chọn, hoặc hardcode)

| Trường       | Kiểu    | Mô tả                                      |
|:-------------|:--------|:--------------------------------------------|
| code         | TEXT PK | USD, VND, EUR                               |
| name         | TEXT    | Dollar, Dong                                |
| rate_to_base | REAL    | Tỷ giá quy đổi sang VND (User tự nhập hoặc fix) |

### 3.4. Cập nhật các bảng cũ

**Table `accounts`:**
- Add `currency_code` (TEXT, Default `'VND'`).
- Add `is_hidden` (BOOLEAN) — Cho tính năng ẩn ví ít dùng.

**Table `transactions`:**
- Add `event_id` (INTEGER FK, Nullable).
- Add `original_currency` (TEXT) — Loại tiền gốc của giao dịch.
- Add `original_amount` (REAL) — Số tiền nguyên tệ.
- Add `exchange_rate` (REAL) — Tỷ giá tại thời điểm giao dịch.

> **Lưu ý:** Cột `amount` cũ vẫn giữ để lưu số tiền đã quy đổi (để tính toán nhanh).

---

## 4. Đặc tả Kỹ thuật (Technical Specs)

### 4.1. Module Bảo mật (Security Implementation)
- **Lưu trữ Key:** Sử dụng `flutter_secure_storage` để lưu mã PIN và Token. Không lưu plaintext trong SharedPrefs.
- **Cơ chế khóa:** Sử dụng `WidgetsBindingObserver` để lắng nghe `AppLifecycleState`. Khi `paused` → Lưu timestamp. Khi `resumed` → Check `now - paused_time > 30s` → Show Lock Screen.

### 4.2. Logic Đa tiền tệ
- Khi hiển thị Tổng tài sản (Net Worth): `Total = Sum(Account.balance * Currency.rate_to_base)`.
- Tỷ giá nên cho phép User tự sửa trong Settings (vì tỷ giá ngân hàng và chợ đen khác nhau).

### 4.3. Logic Tìm kiếm (Full-text Search)
- Sử dụng câu lệnh `LIKE` của SQL cho các trường Text.
- Tối ưu: Đánh Index cho cột `note` và `date`.

---

## 5. Lộ trình Phát triển (Revised Roadmap)

### Phase 1: The Core *(Tuần 1–2)* ✅ Đã hoàn thành
- DB: Accounts, Categories, Transactions.
- UI: Dashboard, Add Transaction, Transaction List.
- Logic: CRUD cơ bản, Tiết kiệm (Transfer).
- Security: Tích hợp khóa App bằng PIN ngay từ đầu.

### Phase 2: Advanced Logic *(Tuần 3)*
- Events: CRUD Sự kiện, Filter theo sự kiện.
- Budgets: Màn hình thiết lập ngân sách, Progress Bar cảnh báo.
- Debts: Quản lý vay/nợ.

### Phase 3: Reports & Intelligence *(Tuần 4)*
- Charts: Pie Chart, Bar Chart (dùng `fl_chart`).
- Search: Xây dựng màn hình tìm kiếm nâng cao.
- Bills: Nhắc nhở hóa đơn.

### Phase 4: Cloud & Sync *(Tuần 5)*
- Tích hợp Google Drive API.
- Xử lý ảnh (Compress, Save Local).
- Cơ chế Backup/Restore JSON + Lazy Load ảnh.

### Phase 5: Polish & Extras *(Tuần 6)*
- Multi-currency: Hoàn thiện logic chuyển đổi tiền tệ.
- OCR: Nghiên cứu tích hợp Google ML Kit (nếu còn thời gian).
- Linux Optimize: Phím tắt, Responsive layout.

---

## 6. Thư viện & Công cụ (Tech Stack)

```yaml
dependencies:
  # Security
  flutter_secure_storage: ^9.0.0     # Lưu PIN an toàn
  local_auth: ^2.1.8                 # Vân tay/FaceID

  # UI Enhancements
  animations: ^2.0.8                 # Hiệu ứng chuyển màn hình mượt
  flutter_slidable: ^3.0.1           # Vuốt để xóa/sửa item
  badges: ^3.1.2                     # Hiển thị số thông báo

  # Charts & Report
  fl_chart: ^0.66.0

  # Search & Filter
  diacritic: ^0.1.5                  # Hỗ trợ tìm kiếm tiếng Việt không dấu

  # OCR (Experimental)
  google_mlkit_text_recognition: ^0.11.0
```

---

## Ghi chú quan trọng

- **Tiếng Việt & Tìm kiếm:** Lưu thêm 1 cột `normalized_note` (chuyển có dấu → không dấu, lowercase) để tìm kiếm nhanh hơn.
- **Khóa App:** Test kỹ trường hợp nhận cuộc gọi hoặc tắt màn hình. Dùng màn hình Splash che khi app `inactive`.
- **Backup:** Có cơ chế "Quên PIN" (reset data hoặc phục hồi qua email/mật khẩu tài khoản).
- Không bắt buộc phải xài database hay thư viện trong gợi ý. Cần chọn phù hợp với mã nguồn cũ, tương thích có các tính năng kia là được.
- Có cơ chế để phục hồi dữ liệu nếu quên mã PIN.