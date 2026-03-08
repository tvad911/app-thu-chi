# Thu Chi - Personal Finance Manager 💰
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)

**Thu Chi** là ứng dụng quản lý tài chính cá nhân tối giản, hiệu quả và hoạt động ngoại tuyến (offline-first). Ứng dụng được thiết kế để giúp bạn kiểm soát dòng tiền, theo dõi các khoản nợ, hóa đơn định kỳ và lập kế hoạch tài chính dài hạn.

## 🚀 Tính năng nổi bật

### 1. Quản lý Ví (Accounts)
- Hỗ trợ đa dạng loại ví: Tiền mặt, Ngân hàng, Thẻ tín dụng, Tiết kiệm, Quỹ, Ví điện tử.
- Cho phép chuyển khoản luân chuyển dòng tiền giữa các ví dễ dàng (không tính vào thu/chi).
- Xem chi tiết lịch sử giao dịch nhanh chóng của từng ví.

### 2. Quản lý Quỹ & Giao dịch (Core)
- **Ghi chép siêu tốc**: Nhập giao dịch chỉ trong 3 giây.
- **Phân loại thông minh**: Tách biệt chi phí **Cố định** (Fixed) và **Không cố định** (Variable) giúp dễ dàng theo dõi và cắt giảm chi tiêu.

### 3. Quản lý Nợ (Debts)
- Ghi nhận chi tiết: "Ai nợ mình" và "Mình nợ ai".
- Hỗ trợ lịch sử thanh toán nợ từng phần, phân tách rõ ràng phần **trả gốc** và **lãi**.
- **Nhắc nhở tự động**: Gửi thông báo khi khoản nợ sắp hoặc quá hạn.

### 4. Tiết kiệm (Savings) & Quỹ Tích Lũy (Goals)
- Tạo sổ tiết kiệm và ghi nhận lãi suất, kỳ hạn tính toán. Tùy chọn đáo hạn thông minh.
- Lên kế hoạch tài chính với tiến độ phần trăm % đạt được mục tiêu tích lũy qua "Quỹ". Tiền gửi vào đây được ẩn khỏi ví chi tiêu hàng ngày.

### 5. Ngân sách (Budgets)
- Giới hạn hạn mức chi tiêu theo tháng + danh mục hiện hành.
- **Thanh cảnh báo trực quan**: Xanh, Vàng, Đỏ tuỳ theo mức độ rủi ro (>= 80%, >= 100%).

### 6. Sự kiện (Events / Travel Mode)
- Gom nhóm chi tiêu trong dịp đặc biệt (như du lịch, tiệc cưới) vào hệ thống ngân sách riêng nhằm tráng bị đội sổ ngân sách của tháng.

### 7. Hóa đơn Định kỳ (Bills)
- Quản lý các khoản chi lặp lại tự động như Điện, Nước, Internet... (Hàng tuần, tháng, năm).
- Nhấp xác nhận tự động tạo Expense tránh quên thanh toán.

### 8. Báo cáo & Thống kê (Reports)
- **Trực quan hóa**: Dashboard đa dạng (Pie Chart, Bar chart) rõ ràng thu/chi trong kì.
- Lọc nâng cao theo Loại, Danh mục, Ví, Khoảng thời gian. Option ẩn số tiền từ Sự kiện.

### 9. Đính kèm & Đồng bộ (Attachments & Cloud)
- **Đính kèm file**: Hóa đơn, chứng từ (Ảnh/PDF) vào từng khoản giao dịch.
- **Nén ảnh khôn khéo**: Tiết kiệm tối đa dung lượng bộ nhớ điện thoại.
- **Cloud Sync**: Hỗ trợ đồng bộ lên Google Drive và S3 Storage (MinIO).
- **Smart Background Sync**: Tự động đồng bộ file định kì ngầm ở chế độ chạy nền.

### 10. Tìm kiếm nâng cao (Advanced Search)
- Tra cứu tiếng việt không dấu đối với Note.
- Lọc theo số tiền giao dịch chính xác.

### 11. An toàn & Riêng tư (Security)
- **Offline First**: Mã hóa và thao tác dữ liệu hoàn toàn bằng SQLite ngay trong máy.
- Khóa bảo mật: Mã PIN, Sinh trắc học (vân tay/Face ID). Chế độ bảo mật "Che số dư" toàn màn hình.
- **Backup JSON**: Xuất và khôi phục toàn bộ cục dữ liệu qua format JSON.

### 12. Giao diện Desktop (Linux/Windows)
- Tự động thay đổi layout 2-cột `NavigationRail` đáp ứng responsive trên màn ảnh rộng Desktop.
- Hỗ trợ hệ thống phím tắt: `Ctrl+N` tạo nhanh, `Ctrl+S` (Save), `Esc` (Dismiss).

---

## 📅 Lịch sử phiên bản (Changelog)

### v1.0.19 — CI/CD & Tài liệu
- **CI/CD Tự động hóa**: Cấu hình đẩy tag Github Actions tự động build APK và publish GitHub Release.
- Tổng hợp toàn bộ đặc tả chi tiết của ứng dụng vào `specs.md` và tinh gọn các quy trình build thủ công vào file `release.md`.

### v1.0.18 — Nút xóa Snapshot, Filter nâng cao & Fix UI
- Triển khai Quản lý Cục bộ Backup Snapshot hiển thị theo list với các shortcut (Khôi phục) hay (Xóa).
- Filter danh mục thu/chi phân biệt rõ ràng 2 nhánh khi tạo Category/Giao dịch.
- Đồng bộ lại hệ thống màu UI Ngân sách tiệp với các chi tiết báo cáo giao dịch chi tiết.

---

## 🛠 Công nghệ sử dụng
- **Framework**: Flutter (Dart).
- **State Management**: Riverpod 2.0.
- **Database**: SQLite (via Drift).
- **Storage**: `flutter_secure_storage` (API Keys), `flutter_image_compress`.
- **Sync**: `googleapis` (Drive), `minio` (S3).
- **Background**: `workmanager`.

## 📸 Screenshots
*(Đang cập nhật)*

## 📦 Cài đặt & Phát triển

### Yêu cầu
- Flutter SDK (Latest Stable)
- Android Studio / VS Code

### Chạy ứng dụng
```bash
# Clone repository
git clone git@github.com:tvad911/app-thu-chi.git

# Vào thư mục project
cd app-thu-chi

# Cài đặt dependencies
flutter pub get

# Chạy App (Chọn thiết bị)
flutter run
```

## 🤝 Đóng góp
Mọi đóng góp (Pull Request) đều được hoan nghênh. Vui lòng mở Issue nếu bạn tìm thấy lỗi.

## 📄 License
MIT License.
