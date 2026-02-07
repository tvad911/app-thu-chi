# Ứng Dụng Quản Lý Thu Chi

Ứng dụng quản lý tài chính cá nhân hiện đại, bảo mật và mạnh mẽ, được xây dựng bằng Flutter cho nền tảng Android và Linux.

## 🚀 Tính Năng Nổi Bật

### 1. Quản Lý Tài Chính Toàn Diện
- **Dashboard**: Cái nhìn tổng quan về tình hình tài chính trong tháng.
- **Thu/Chi**: Ghi chép giao dịch nhanh chóng với phân loại danh mục chi tiết.
- **Ví (Accounts)**: Quản lý nhiều nguồn tiền (Tiền mặt, Thẻ, Tiết kiệm).

### 2. Ngân Sách Thông Minh (Smart Budget)
- Thiết lập hạn mức chi tiêu cho từng danh mục (Ví dụ: Ăn uống 3 triệu/tháng).
- **Cảnh báo tự động**: Nhận thông báo khi chi tiêu vượt quá 80%, 90% hoặc 100% hạn mức.

### 3. Sự Kiện & Chuyến đi (Events)
- Tách biệt chi tiêu cho các dịp đặc biệt (Du lịch, Đám cưới) để không ảnh hưởng báo cáo hàng tháng.
- Theo dõi ngân sách riêng cho từng sự kiện.

### 4. Báo Cáo Trực Quan
- Biểu đồ tròn (Pie Chart) phân tích cơ cấu chi tiêu.
- Thống kê chi tiết theo thời gian.

### 5. Offline-First & Bảo Mật
- Dữ liệu được lưu trữ cục bộ trên thiết bị (SQLite), đảm bảo quyền riêng tư tuyệt đối.
- Không yêu cầu kết nối internet để hoạt động.

## 🛠 Cài Đặt và Build

### Yêu Cầu Hệ Thống
- **Flutter SDK**: >= 3.0.0
- **Android**: Android SDK, Java 11/17.
- **Linux**: Clang, CMake, Ninja, GTK 3.0 (`libgtk-3-dev`).

### Lệnh Build (Releases)

#### Linux App
```bash
flutter build linux --release
```
> Kết quả: `build/linux/x64/release/bundle/thuchi_app`

#### Android APK
```bash
flutter build apk --release
```
> Kết quả: `build/app/outputs/flutter-apk/app-release.apk`

## ✅ Trạng Thái Phát Triển (Dev Status)

- **Version**: 1.0.0+1
- **Testing**:
  - Unit Tests: Đã hoàn tất và vượt qua các kiểm tra logic quan trọng (Tiền tệ, Database, Service).
  - Integration: Đang cập nhật.

## 🤝 Đóng Góp
Mọi đóng góp xin vui lòng tạo Pull Request hoặc Issue trên repository này.

---
© 2024 Thu Chi Management. Built with ❤️ using Flutter.
