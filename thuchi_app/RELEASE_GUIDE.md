# Hướng dẫn Phát hành Cập nhật (Release Guide)

Tài liệu này hướng dẫn quy trình đóng gói và phát hành phiên bản mới cho ứng dụng Quản lý Thu Chi thông qua GitHub Releases.

## 1. Chuẩn bị phiên bản mới

Trước khi build, hãy cập nhật phiên bản trong file `pubspec.yaml`.

```yaml
version: 1.0.11+11  # Thay đổi phiên bản ở đây (Major.Minor.Patch+BuildNumber)
```

- **Major.Minor.Patch**: Phiên bản hiển thị cho người dùng (ví dụ: 1.0.11).
- **BuildNumber**: Số build nội bộ (tăng dần, ví dụ: +11).

## 2. Tạo bản Build (APK)

Chạy lệnh sau để tạo file APK release:

```bash
flutter build apk --release --no-tree-shake-icons
```

File APK sẽ được tạo tại: `build/app/outputs/flutter-apk/app-release.apk`

## 3. Tạo Release trên GitHub

1.  Truy cập repository trên GitHub: [https://github.com/tvad911/app-thu-chi/releases](https://github.com/tvad911/app-thu-chi/releases)
2.  Nhấn nút **"Draft a new release"**.
3.  **Choose a tag**: Tạo tag mới tương ứng với phiên bản trong `pubspec.yaml`.
    *   Quy tắc đặt tên: `v` + `Phiên bản` (ví dụ: `v1.0.11`).
    *   *Lưu ý: Ứng dụng sẽ dựa vào tag này để kiểm tra cập nhật.*
4.  **Release title**: Đặt tiêu đề (ví dụ: `Phiên bản 1.0.11 - Cập nhật tính năng ABC`).
5.  **Describe this release**: Ghi chú các thay đổi, tính năng mới, hoặc sửa lỗi. Nội dung này sẽ hiển thị trong ứng dụng khi người dùng kiểm tra cập nhật.
6.  **Attach binaries**: Kéo thả file `app-release.apk` (từ bước 2) vào khu vực này.
7.  Nhấn **"Publish release"**.

## 4. Kiểm tra trên ứng dụng

1.  Mở ứng dụng Quản lý Thu Chi (phiên bản cũ hơn).
2.  Vào **Cài đặt** -> **Về ứng dụng**.
3.  Ứng dụng sẽ tự động kiểm tra và hiển thị thông báo cập nhật mới.
4.  Nhấn **"Cập nhật ngay"** để tải file APK về và cài đặt.

## Lưu ý quan trọng

- **Tag Name**: Bắt buộc phải bắt đầu bằng chữ `v` (ví dụ `v1.0.0`) để logic trong app hoạt động chính xác.
- **Pre-release**: Nếu tích vào ô "Set as a pre-release", logic hiện tại vẫn sẽ nhận diện là bản mới nhất nếu tag name cao hơn.
