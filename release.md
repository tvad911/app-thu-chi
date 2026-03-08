# Hướng dẫn Build & Phát hành Ứng dụng

Tài liệu hướng dẫn quy trình đóng gói và phát hành phiên bản mới cho ứng dụng Quản lý Thu Chi.

## 1. Chuẩn bị phiên bản mới

Cập nhật phiên bản trong file `thuchi_app/pubspec.yaml`:

```yaml
version: 1.0.18+18  # Major.Minor.Patch+BuildNumber
```

- **Major.Minor.Patch**: Phiên bản hiển thị cho người dùng.
- **BuildNumber**: Số build nội bộ (tăng dần).

Đồng thời cập nhật `version.json` tại root repo với version, build_number và release_notes tương ứng.

## 2. Làm sạch và Build

Mở terminal tại thư mục `thuchi_app/`:

```bash
cd /đường/dẫn/đến/thuchi/thuchi_app/
flutter clean
flutter pub get
```

### Build Android (APK)

```bash
flutter build apk --release --no-tree-shake-icons
```

File output: `build/app/outputs/flutter-apk/app-release.apk`

### Build Android (App Bundle - cho Google Play)

```bash
flutter build appbundle --release --no-tree-shake-icons
```

File output: `build/app/outputs/bundle/release/app-release.aab`

### Build Linux Desktop

```bash
flutter build linux --release
```

File output: `build/linux/x64/release/bundle/thuchi_app`

### Build Web

```bash
flutter build web --release
```

File output: `build/web/`

## 3. Tạo Release trên GitHub

1. Truy cập: [https://github.com/tvad911/app-thu-chi/releases](https://github.com/tvad911/app-thu-chi/releases)
2. Nhấn **"Draft a new release"**
3. **Choose a tag**: Tạo tag mới theo format `v` + version (ví dụ: `v1.0.18`)
   - *Ứng dụng dựa vào tag này để kiểm tra cập nhật*
4. **Release title**: Đặt tiêu đề mô tả (ví dụ: `v1.0.18 — Xóa snapshot, Filter danh mục`)
5. **Describe this release**: Copy nội dung từ `thuchi_app/RELEASE_NOTES.md`
6. **Attach binaries**: Kéo thả file `app-release.apk` vào
7. Nhấn **"Publish release"**

## 4. Kiểm tra trên ứng dụng

1. Mở ứng dụng (phiên bản cũ)
2. Vào **Cài đặt** → **Về ứng dụng**
3. Ứng dụng tự kiểm tra và hiển thị thông báo cập nhật
4. Nhấn **"Cập nhật ngay"** để tải APK về và cài đặt

## Lưu ý quan trọng

- **Tag Name**: Bắt buộc bắt đầu bằng `v` (ví dụ `v1.0.18`) để logic kiểm tra cập nhật trong app hoạt động.
- **Pre-release**: Nếu tích "Set as a pre-release", app vẫn nhận diện là bản mới nếu tag name cao hơn.
