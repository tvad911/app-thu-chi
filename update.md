# Hướng dẫn Update ứng dụng bằng Git

Tài liệu này hướng dẫn cách sử dụng Git để cập nhật ứng dụng của bạn lên phiên bản mới nhất từ kho lưu trữ (repository) một cách an toàn và dễ dàng.

## Lưu ý trước khi update
Hãy đảm bảo bạn đã lưu hoặc commit các thay đổi cá nhân (nếu có) trên máy của mình trước khi thực hiện pull code mới. Nếu không có thay đổi nào quan trọng (chỉ sử dụng app), bạn có thể thực hiện thẳng các lệnh phía dưới để cập nhật.

## Quy trình cập nhật (Update)

1. **Mở terminal (trên server hoặc máy cá nhân của bạn)**
2. **Truy cập vào thư mục của hệ thống**, ví dụ:
   ```bash
   cd /đường/dẫn/đến/thư/mục/thuchi/
   ```

3. **Lấy danh sách các bản cập nhật mới nhất (tags) từ kho ứng dụng (Remote):**
   ```bash
   git fetch --all --tags
   ```

4. **Chuyển sang (Checkout) phiên bản mới nhất an toàn:**
   Để cập nhật ứng dụng lên bản release (tag/phiên bản đóng gói) mới nhất ổn định (ví dụ v1.0.12), bạn chạy lệnh sau:
   ```bash
   # Tự động lấy tag phát hành mới nhất báo hiệu bản cập nhật
   LATEST_TAG=$(git describe --tags `git rev-list --tags --max-count=1`)
   
   # Cập nhật code sang phiên bản mới nhất đó
   git checkout $LATEST_TAG
   ```
   *Lưu ý: Nếu bạn đang muốn theo dõi trực tiếp nhánh đang phát triển (`main`) để nhận cập nhật liên tục từng giây (dành cho lập trình viên), bạn có thể chạy: `git pull origin main` thay thế.*

5. **Giải quyết xung đột (Nếu có lỗi "uncommitted changes"):**
   Đôi khi có lỗi báo bạn vô tình sửa đổi file cục bộ nên không update được, nếu bạn chắc chắn muốn HUỶ thay đổi của mình để ghi đè cập nhật mới tinh:
   ```bash
   git reset --hard HEAD
   # Sau đó chạy lệnh git checkout $LATEST_TAG lại lần nữa
   ```

6. **Build/Refresh lại ứng dụng:**
   Sau khi nâng cấp phiên bản bằng Git, bạn cần build qua công cụ tùy vào môi trường dự án hoặc khởi động lại container:
   ```bash
   # Ví dụ khởi động lại Docker compose hoặc Flutter build
   docker compose restart
   # Hoặc với Flutter
   cd thuchi_app
   flutter pub get
   ```

## Khôi phục lại phiên bản cũ (Rollback) nếu bị lỗi sau khi update:
Nếu sau khi phiên bản mới cập nhật có rủi ro về lỗi phát sinh, bạn có thể hoàn tác xuống phiên bản cũ hơn hoạt động ổn định liền kề:
```bash
# Xem danh sách các phiên bản (tags) hiện có
git tag -l

# Khôi phục về chính xác mốc phiên bản cũ yêu cầu (ví dụ v1.0.11)
git checkout v1.0.11
```
