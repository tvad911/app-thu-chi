
Dưới đây là file plan_debt.md tách riêng, chuyên biệt cho module Quản lý Nợ & Cho Vay. Bạn có thể lưu file này vào thư mục tài liệu dự án để dễ theo dõi tiến độ code.
MODULE SPEC: Debt Management (Quản lý Nợ & Cho Vay)
Ngày tạo: 06/02/2026
Trạng thái: Draft
Mục tiêu: Quản lý các khoản vay nợ, theo dõi tiến độ trả nợ, tách biệt tiền gốc/lãi và nhắc hạn thanh toán.
1. Cơ sở dữ liệu (Database Schema)
Cần tạo mới bảng debts và cập nhật bảng transactions.
1.1. Bảng debts (Sổ nợ)
Lưu trữ thông tin định danh của khoản vay.
Trường (Field)	Kiểu (Type)	Mô tả
id	INTEGER PK	Auto increment
transaction_type	TEXT	BORROW (Mình đi vay), LEND (Mình cho vay)
partner_name	TEXT	Tên đối tác (VD: "Ngân hàng VCB", "Anh Nam")
total_amount	REAL	Số tiền gốc ban đầu
remaining_amount	REAL	Số tiền gốc còn lại chưa trả
interest_rate	REAL	Lãi suất (VD: 12.5)
interest_type	TEXT	PERCENT_YEAR (%/năm), PERCENT_MONTH (%/tháng), FIXED (Số tiền cố định)
start_date	INTEGER	Unix Timestamp: Ngày bắt đầu vay
due_date	INTEGER	Unix Timestamp: Hạn chót phải trả
notify_days	INTEGER	Số ngày nhắc trước hạn (VD: 3 ngày)
is_finished	BOOLEAN	true nếu đã tất toán (remaining = 0)
note	TEXT	Ghi chú thêm
1.2. Cập nhật bảng transactions
Thêm liên kết để biết giao dịch thu/chi này thuộc về khoản nợ nào.
Thêm cột: debt_id (INTEGER, Nullable).
Logic:
Nếu debt_id != NULL: Đây là giao dịch trả nợ/thu nợ.
Cần phân biệt phần Gốc và Lãi trong giao dịch (Xem phần Logic nghiệp vụ).
2. Logic Nghiệp vụ (Business Logic)
2.1. Tạo khoản nợ mới (Create)
Đi vay (Borrow):
Tạo record trong bảng debts.
Tự động tạo giao dịch IN (Tiền vào) cho Ví được chọn (VD: Tiền mặt).
Lưu ý: Giao dịch này KHÔNG tính là Income (Thu nhập) để tránh sai lệch báo cáo thuế/lợi nhuận.
Cho vay (Lend):
Tạo record trong bảng debts.
Tự động tạo giao dịch OUT (Tiền ra) từ Ví được chọn.
Lưu ý: Giao dịch này KHÔNG tính là Expense (Chi tiêu).
2.2. Thanh toán nợ (Repayment)
Khi người dùng thực hiện trả tiền (hoặc thu tiền về), hệ thống cần yêu cầu nhập 2 số liệu: Tiền Gốc và Tiền Lãi.
Input: Tổng tiền trả, tách ra Gốc (Principal) và Lãi (Interest).
Xử lý Gốc:
Tạo Transaction (Type: Transfer/Adjustment).
Trừ tiền trong Ví nguồn.
Trừ remaining_amount trong bảng debts.
Nếu remaining_amount <= 0 -> Update is_finished = true.
Xử lý Lãi:
Tạo Transaction (Type: EXPENSE nếu đi vay, INCOME nếu cho vay).
Trừ/Cộng tiền trong Ví.
Ghi nhận vào Báo cáo Thu Chi (Vì lãi là chi phí/thu nhập thực).
2.3. Hệ thống nhắc nhở (Notification System)
Sử dụng WorkManager (Android) chạy định kỳ mỗi ngày 1 lần (Daily Job).
Query: Tìm các debts có is_finished = false.
Check: Nếu (due_date - current_date) <= notify_days.
Action: Bắn Local Notification: "Đến hạn trả 5tr cho [Name] vào ngày [Date]".
3. Giao diện Người dùng (UI/UX)
3.1. Màn hình Danh sách Nợ (Debt List)
Dùng TabBar: 2 Tab "Đi vay" (Màu đỏ chủ đạo) và "Cho vay" (Màu xanh chủ đạo).
Item Card:
Tên người.
Thanh tiến trình (Progress Bar): Đã trả được bao nhiêu %.
Số tiền còn lại / Tổng gốc.
Hạn trả (Highlight màu đỏ nếu sắp đến hạn).
3.2. Màn hình Chi tiết Nợ (Debt Detail)
Thông tin chung (Lãi suất, ngày vay, ngày trả).
Nút "Thêm giao dịch" (Trả nợ/Thu nợ):
Popup hoặc màn hình riêng.
Ô nhập: Số tiền trả.
Checkbox/Switch: "Có bao gồm lãi không?".
Nếu có -> Hiện thêm ô nhập "Tiền lãi".
Lịch sử thanh toán (History):
List các transaction liên kết với debt_id này.
4. Kế hoạch Code (Implementation Steps)
Phase 1: Database & Model (Ngày 1)
Viết Entity Debt trong Drift/SQLite.
Viết Migration: Alter table Transaction add column debt_id.
Chạy build_runner để sinh code database.
Phase 2: Repository & Logic (Ngày 2)
Viết hàm createDebt(): Transactional (Tạo nợ + Update ví).
Viết hàm addRepayment(debtId, principal, interest):
Update Debt Balance.
Insert Transaction (Gốc).
Insert Transaction (Lãi - nếu có).
Phase 3: UI Implementation (Ngày 3-4)
Build màn hình List Debts.
Build màn hình Detail & Form thêm trả nợ.
Test logic: Thử trả hết nợ xem status có chuyển sang Finished không.
Phase 4: Notification (Ngày 5)
Setup flutter_local_notifications.
Setup workmanager.
Viết logic check ngày và push thông báo background.
5. Lưu ý cho JSON Backup
Cấu trúc JSON cần thêm trường debts.
code
JSON
"debts": [
  {
    "id": 1,
    "transaction_type": "BORROW",
    "partner_name": "Anh A",
    "total_amount": 1000000,
    "remaining_amount": 500000,
    "interest_rate": 0,
    "interest_type": "FIXED",
    "start_date": 1707188400000,
    "due_date": 1709188400000,
    "notify_days": 1,
    "is_finished": false
  }
]