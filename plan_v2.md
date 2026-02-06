# SPEC-002: Các tính năng còn lại & Lộ trình phát triển
**Ngày cập nhật:** 06/02/2026
**Trạng thái:** Đang phát triển (Phase 2 & Phase 3)

---

## 1. Các Module Chức năng Cần làm (Remaining Features)

### 1.1. Quản lý Hóa đơn (Bills) - **Mức độ ưu tiên: Cao**
**Mục đích**: Nhắc nhở và tự động hóa các khoản chi định kỳ (Điện, Nước, Internet, Netflix...).

**Logic nghiệp vụ**:
- **Chu kỳ lặp**: Hàng tháng, Hàng tuần, Hàng năm.
- **Trạng thái**: Chờ thanh toán, Đã thanh toán, Quá hạn.
- **Hành động "Thanh toán"**:
    - Khi người dùng xác nhận thanh toán một hóa đơn:
        1. Tự động tạo một `Transaction` (Chi tiêu) tương ứng.
        2. Cập nhật trạng thái Bill kỳ này thành `Đã trả`.
        3. Tự động sinh ra Bill cho kỳ tiếp theo (Dựa trên chu kỳ lặp).

**Yêu cầu UI**:
- Danh sách Hóa đơn (Sắp xếp theo ngày đến hạn).
- Form thêm/sửa Hóa đơn (Chọn chu kỳ, ngày nhắc).
- Tabs: Sắp đến hạn | Đã trả.

---

### 1.2. Đồng bộ & Backup Nâng cao (Media & Cloud)
**Mục đích**: Bảo vệ dữ liệu và giải phóng dung lượng máy.

**Logic Xử lý Ảnh (Image Processor)**:
- **Input**: Ảnh từ Camera/Gallery.
- **Action**:
    - Resize: Max width/height 1024px.
    - Compress: JPEG quality 70-80% (Sử dụng `flutter_image_compress`).
    - Lưu vào thư mục riêng của App (`AppDocDir/attachments/`).

**Google Drive Sync Service**:
- **Cơ chế**: Sync 1 chiều (Local -> Drive) hoặc 2 chiều đơn giản.
- **Upload**:
    - Cơ chế Background Job (WorkManager).
    - Upload ảnh lên thư mục `MyFinanceApp` trên Drive.
    - Lấy `file_id` từ Drive cập nhật lại vào DB local.
- **Lazy Load**:
    - Khi Restore hoặc xem lại trên máy mới: Chỉ tải metadata.
    - Ảnh chỉ được tải về (download) khi người dùng bấm xem chi tiết.

---

## 2. Thiết kế Cơ sở dữ liệu (Schema Cần bổ sung)

Các bảng hiện tại đã ổn (`accounts`, `categories`, `transactions`, `debts`). Cần bổ sung/hoàn thiện các bảng sau cho tính năng mới:

### 2.1. Table `bills` (Mới)
| Column | Type | Description |
|--------|------|-------------|
| id | Int | PK |
| title | String | Tên hóa đơn (VD: Tiền điện) |
| amount | Real | Số tiền dự kiến |
| due_date | DateTime | Ngày đến hạn kỳ tới |
| repeat_cycle | String | MONTHLY, WEEKLY, YEARLY |
| notify_before | Int | Nhắc trước (ngày) |
| category_id | Int | FK -> categories |
| user_id | String | Chủ sở hữu |

### 2.2. Table `attachments` (Mới - Quản lý File/Ảnh)
| Column | Type | Description |
|--------|------|-------------|
| id | Int | PK |
| transaction_id | Int | FK -> transactions (Nullable) |
| debt_id | Int | FK -> debts (Nullable) |
| file_name | String | Tên file local (VD: img_123.jpg) |
| local_path | String | Đường dẫn tương đối |
| drive_file_id | String | ID trên Google Drive (Nullable) |
| sync_status | String | PENDING, SYNCED, ERROR |

---

## 3. Lộ trình cập nhật (Updated Roadmap)

### Phase 2.5: Quản lý Hóa đơn (Bills)
- [ ] Tạo bảng `bills` trong Database.
- [ ] Tạo `BillRepository` logic lặp lại.
- [ ] UI: Màn hình danh sách & chi tiết hóa đơn.
- [ ] Tích hợp Notification nhắc hóa đơn (Kết hợp service hiện có).

### Phase 3: Media & Cloud Sync
- [ ] Thêm dependencies: `flutter_image_compress`, `google_sign_in`, `googleapis`.
- [ ] Implement `ImageHelper`: Nén và lưu ảnh local.
- [ ] Implement `DriveService`:
    - Đăng nhập Google.
    - Quản lý Folder trên Drive.
    - Upload/Download file.
- [ ] Cập nhật UI Transaction/Debt: Cho phép đính kèm ảnh.

### Phase 4: Polish & Optimization
- [ ] Review UI trên Desktop (Linux).
- [ ] Test toàn bộ luồng Backup/Restore (Bao gồm settings mới).
- [ ] Kiểm tra dark mode/light mode.

---

## 4. Ghi chú Dependencies cần thêm
```yaml
dependencies:
  # Image & Files
  flutter_image_compress: ^2.1.0
  
  # Google Drive Integration  
  google_sign_in: ^6.2.1
  googleapis: ^13.1.0
  extension_google_sign_in_as_googleapis_auth: ^2.0.12
```