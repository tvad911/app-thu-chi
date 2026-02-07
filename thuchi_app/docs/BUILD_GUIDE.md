# Hướng dẫn Build Release

## 1. Build Linux App (Desktop)

Yêu cầu hệ thống:
- Clang, CMake, Ninja, GTK development headers.
- `sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev`

Lệnh build:
```bash
flutter build linux --release
```
Kết quả nằm tại: `build/linux/x64/release/bundle/`
Chạy thử: `./build/linux/x64/release/bundle/thuchi_app`

## 2. Build Android App

### a. App Bundle (AAB - Recommended for Play Store)
```bash
flutter build appbundle --release
```
Kết quả: `build/app/outputs/bundle/release/app-release.aab`

### b. APK (Sideloading)
```bash
flutter build apk --release
```
Kết quả: `build/app/outputs/flutter-apk/app-release.apk`

## 3. Versioning

Để tăng version, sửa file `pubspec.yaml`:
```yaml
version: 1.0.1+2
```
Trong đó `1.0.1` là tên phiên bản hiển thị, `+2` là mã xây dựng (build number - integer tăng dần).

## 4. Troubleshooting

Nếu gặp lỗi build Android liên quan đến Gradle/Java:
- Kiểm tra `android/build.gradle`.
- Đảm bảo `JAVA_HOME` trỏ đúng JDK 17 (tương thích Gradle 8).

Nếu gặp lỗi Linux:
- `pkg-config` không tìm thấy thư viện: Cài đặt lại `libgtk-3-dev`.
