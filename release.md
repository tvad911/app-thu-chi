# Hướng dẫn Build (Đóng gói) Ứng dụng để Phát hành

Trước khi tiến hành build phiên bản *Release*, bạn cần đảm bảo đã cấu hình đúng thông tin phiên bản trong file `pubspec.yaml` (ví dụ `version: 1.0.12+12`).

Sau đó, dọn dẹp các bộ nhớ đệm (cache) cũ và cập nhật lại thư viện để tránh các lỗi xung đột phần mềm:

1. **Mở terminal và di chuyển vào đúng thư mục chứa code Flutter:**
   ```bash
   cd /đường/dẫn/đến/thư/mục/thuchi/thuchi_app/
   ```
   *(Lưu ý: Bắt buộc phải đứng ở thư mục `thuchi_app` chứa file `pubspec.yaml` để chạy các lệnh Flutter)*

2. **Chạy các lệnh làm sạch trước khi build:**
   ```bash
   flutter clean
   flutter pub get
   ```

Tùy vào nền tảng bạn muốn phát hành (Android, Linux, Web...), hãy tiếp tục chạy các lệnh build tương ứng phía dưới:

## 1. Build cho Android
**Tạo file APK:** Đây là file cài đặt thông dụng nhất. Bạn có thể tải file này thẳng lên mục **Release** của GitHub để người khác có thể tải về và cài đặt ngay trên điện thoại Android của họ.
```bash
flutter build apk --release --no-tree-shake-icons
```
*Đường dẫn file sau khi hoàn tất:* `build/app/outputs/flutter-apk/app-release.apk`
*(Lấy file `app-release.apk` này upload lên Github Release)*

**Tạo định dạng App Bundle (.aab):** Sử dụng chuẩn nén này nếu mục đích của bạn là đẩy ứng dụng lên cửa hàng **Google Play Store**.
```bash
flutter build appbundle --release --no-tree-shake-icons
```
*Đường dẫn file sau khi hoàn tất:* `build/app/outputs/bundle/release/app-release.aab`

## 2. Build cho Desktop (Hệ Điều Hành Linux)
Để tạo ra phiên bản ứng dụng thực thi tự chạy trực tiếp trên máy tính hệ điều hành Linux:
```bash
flutter build linux --release
```
*Đường dẫn ứng dụng sau khi hoàn tất nằm tại:* `build/linux/x64/release/bundle/thuchi_app`

## 3. Build cho Website (Web App)
Nếu bạn muốn tải ứng dụng này lên mạng host thành giao diện web (như Vercel, Firebase Hosting...):
```bash
flutter build web --release
```
*Đường dẫn thư mục web build nằm tại:* `build/web/`
