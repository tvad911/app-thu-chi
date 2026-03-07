---
description: Tạo release mới - commit, tag, push, build APK, soạn release notes
---

# Release Workflow

Khi user yêu cầu "release" hoặc "thêm release skill", thực hiện các bước sau:

## Bước 1: Xác định version mới

1. Đọc `version.json` tại root repo để lấy version hiện tại (ví dụ `1.0.17`)
2. Đọc `thuchi_app/pubspec.yaml` để xác nhận version + build_number
3. Tăng version: `1.0.X` → `1.0.(X+1)`, build_number tương ứng
4. Cập nhật cả 2 file:
   - `version.json`: bump `version`, `build_number`, cập nhật `release_notes` (1 dòng tóm tắt tiếng Việt)
   - `thuchi_app/pubspec.yaml`: bump `version: X.Y.Z+build_number`

## Bước 2: Commit code

1. Chạy `git status --short` để xem danh sách files thay đổi
2. Soạn commit message theo format:

```
feat: vX.Y.Z - <tóm tắt ngắn bằng tiếng Việt>

- <chi tiết thay đổi 1>
- <chi tiết thay đổi 2>
- ...
```

3. Chạy:
```bash
// turbo
cd /home/anhduong/docker/rust/thuchi && git add -A
```

4. Commit (KHÔNG auto-run, cần user xác nhận):
```bash
git commit -m "<commit message đã soạn>"
```

## Bước 3: Tạo tag + push

```bash
git tag vX.Y.Z && git push origin main --tags
```

## Bước 4: Build APK

```bash
cd /home/anhduong/docker/rust/thuchi/thuchi_app && flutter build apk --release --no-tree-shake-icons 2>&1 | tail -15
```

APK output: `thuchi_app/build/app/outputs/flutter-apk/app-release.apk`

## Bước 5: Soạn release notes (.md)

Tạo file `thuchi_app/RELEASE_NOTES.md` (overwrite) với nội dung markdown theo format sau:

```markdown
# vX.Y.Z — <Tiêu đề ngắn gọn>

## ✨ Tính năng mới

### <Emoji> <Tên tính năng 1>
- Chi tiết thay đổi
- Chi tiết thay đổi

### <Emoji> <Tên tính năng 2>
- Chi tiết thay đổi

## 🐛 Sửa lỗi (nếu có)
- Mô tả lỗi đã sửa

## 🗄️ Kỹ thuật (nếu có thay đổi DB/infrastructure)
- Mô tả kỹ thuật

## 📦 Tải về
- [app-release.apk](https://github.com/tvad911/app-thu-chi/releases/download/vX.Y.Z/app-release.apk)
```

**Lưu ý:**
- Nội dung viết bằng tiếng Việt
- Dùng emoji phù hợp cho từng nhóm tính năng
- Chỉ liệt kê những gì thực sự thay đổi trong lần release này
- File `RELEASE_NOTES.md` nằm tại `thuchi_app/RELEASE_NOTES.md` để user dễ mở và copy

## Bước 6: Thông báo user

Thông báo cho user:
- Commit hash + message
- Tag đã tạo
- APK path + size
- Mở file `RELEASE_NOTES.md` để user review và copy vào GitHub release
