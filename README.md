# Thu Chi - Personal Finance Manager 💰
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)

**Thu Chi** là ứng dụng quản lý tài chính cá nhân tối giản, hiệu quả và hoạt động ngoại tuyến (offline-first). Ứng dụng được thiết kế để giúp bạn kiểm soát dòng tiền, theo dõi các khoản nợ, hóa đơn định kỳ và lập kế hoạch tài chính dài hạn.

## 🚀 Tính năng nổi bật

### 1. Quản lý Thu Chi & Ví
- **Ghi chép siêu tốc**: Nhập giao dịch chỉ trong 3 giây.
- **Phân loại thông minh**:
    - **Cố định (Fixed)**: Tiền nhà, điện nước, trả góp...
    - **Không cố định (Variable)**: Ăn uống, mua sắm, giải trí... (Nơi bạn có thể cắt giảm).
- **Đa nền tảng**: Hỗ trợ ví Tiền mặt, Ngân hàng, Thẻ tín dụng, Ví điện tử.
- **Chuyển khoản**: Luân chuyển tiền giữa các ví dễ dàng.

### 2. Quản lý Nợ (Debt Management)
- Theo dõi: "Ai nợ mình" và "Mình nợ ai".
- Lịch sử trả nợ từng phần.
- **Nhắc nhở**: Thông báo tự động khi sắp đến hạn trả nợ.

### 3. Hóa đơn Định kỳ (Bills)
- Quản lý các khoản chi lặp lại (Điện, Nước, Internet, Netflix...).
- Tự động tạo giao dịch khi xác nhận thanh toán.
- Chu kỳ linh hoạt: Hàng tuần, Hàng tháng, Hàng năm.

### 4. Đính kèm & Đồng bộ (Attachments & Cloud)
- **Đính kèm**: Hóa đơn, chứng từ (Ảnh/PDF) vào giao dịch.
- **Nén ảnh tự động**: Tiết kiệm dung lượng lưu trữ.
- **Cloud Sync**: 
    - Hỗ trợ **Google Drive** và **S3 Storage** (MinIO, AWS...).
    - **Background Sync**: Tự động đồng bộ file ngầm định kỳ (1 giờ/lần) khi có mạng.
    - **Smart Upload**: Chỉ upload file mới hoặc thay đổi.

### 5. Giao diện Desktop (Linux/Windows)
- **Responsive**: Tự động chuyển đổi layout (NavigationRail 2 cột trên màn hình rộng).
- **Phím tắt (Shortcuts)**:
    - `Ctrl + N`: Thêm giao dịch nhanh.
    - `Ctrl + S`: Lưu form.
    - `Esc`: Thoát/Hủy.

### 6. An toàn & Riêng tư
- **Offline First**: Dữ liệu nằm hoàn toàn trên thiết bị của bạn.
- **Backup/Restore**: Sao lưu toàn bộ dữ liệu (bao gồm cả Attachments Metadata & Bills) ra file JSON.
- **Quyền riêng tư**: Không thu thập dữ liệu người dùng.

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
