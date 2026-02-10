# Logic Nghiệp vụ & Mô hình Dòng tiền (Business Logic & Cashflow)

Đây là tài liệu cực kỳ quan trọng về mặt **Logic Nghiệp vụ (Business Logic)**. Nếu xử lý sai mối quan hệ này, báo cáo tài chính của người dùng sẽ bị sai lệch (Ví dụ: Đi vay tiền mà lại tưởng là mình giàu lên do Thu nhập tăng).

Để xây dựng ứng dụng chuẩn, cần phân biệt rõ hai khái niệm: **Dòng tiền (Cashflow)** và **Thu/Chi (Income/Expense)**.

Dưới đây là bảng phân tích mối quan hệ logic chi tiết để triển khai code:

---

## 1. Mối Quan Hệ: Vay & Cho Vay (Debts)

**Quy tắc cốt lõi:**
*   **Tiền Gốc (Principal):** Là luân chuyển tài sản (Transfer).
*   **Tiền Lãi (Interest):** Mới là Thu nhập (Income) hoặc Chi phí (Expense).

### A. Đi vay (Borrowing) - Bạn nhận tiền từ người khác

| Hành động | Loại giao dịch | Tác động lên Ví (Wallet) | Tác động lên Báo cáo (Report) | Tác động lên Sổ nợ (Debt) |
| :--- | :--- | :--- | :--- | :--- |
| **Nhận tiền vay** | `Transfer In` (Tiền vào) | Tăng (+) | **Không** tính là Thu nhập (Vì phải trả lại) | Tạo khoản nợ mới (Gốc) |
| **Trả nợ (GỐC)** | `Transfer Out` (Tiền ra) | Giảm (-) | **Không** tính là Chi tiêu | Giảm số nợ gốc còn lại |
| **Trả nợ (LÃI)** | `Expense` (Chi tiêu) | Giảm (-) | **Tính** vào Chi tiêu (Mất đi vĩnh viễn) | Không giảm gốc (Hoặc ghi nhận lịch sử lãi) |

**Logic Code:**
```dart
// Khi user bấm "Trả nợ": Tách số tiền làm 2 phần (Gốc & Lãi).
Wallet.balance -= (Gốc + Lãi);
Debt.remaining_amount -= Gốc;
Report.total_expense += Lãi;
```

### B. Cho vay (Lending) - Bạn đưa tiền cho người khác

| Hành động | Loại giao dịch | Tác động lên Ví (Wallet) | Tác động lên Báo cáo (Report) | Tác động lên Sổ nợ (Debt) |
| :--- | :--- | :--- | :--- | :--- |
| **Cho mượn** | `Transfer Out` (Tiền ra) | Giảm (-) | **Không** tính là Chi tiêu (Vì sẽ đòi lại được) | Tạo khoản phải thu mới |
| **Thu nợ (GỐC)** | `Transfer In` (Tiền vào) | Tăng (+) | **Không** tính là Thu nhập | Giảm số nợ gốc còn lại |
| **Thu nợ (LÃI)** | `Income` (Thu nhập) | Tăng (+) | **Tính** vào Thu nhập (Tiền lời sinh ra) | Không giảm gốc |

---

## 2. Mối Quan Hệ: Gửi Tiết Kiệm (Savings)

**Quy tắc cốt lõi:** Tiết kiệm là hành động chuyển tiền từ túi này sang túi khác. **Tổng tài sản không đổi.**

| Hành động | Loại giao dịch | Tác động lên Ví Chính | Tác động lên Ví Tiết Kiệm | Tác động lên Báo cáo Thu/Chi |
| :--- | :--- | :--- | :--- | :--- |
| **Gửi tiền** | `Transfer` | Giảm (-) | Tăng (+) | **Không** tính (Tài sản giữ nguyên) |
| **Rút gốc** | `Transfer` | Tăng (+) | Giảm (-) | **Không** tính |
| **Nhận lãi** | `Income` | Tăng (+) (Nếu lãi về ví chính) | Tăng (+) (Nếu lãi nhập gốc) | **Tính** là Thu nhập (Đầu tư sinh lời) |

**Logic Code:**
*   Cần có loại ví **SAVING**.
*   Khi báo cáo *"Chi tiêu tháng này"*: Phải **loại trừ** các giao dịch `Transfer` liên quan đến ví Saving.
    *   *Lý do:* Nếu không App sẽ báo tháng này tiêu hết sạch lương (do gửi tiết kiệm hết), gây hiểu lầm.

---

## 3. Mối Quan Hệ: Hóa Đơn (Bills)

**Quy tắc cốt lõi:** Hóa đơn là lời nhắc. Khi thanh toán hóa đơn, nó trở thành **Chi phí (Expense)**.

| Hành động | Loại giao dịch | Tác động lên Ví (Wallet) | Tác động lên Báo cáo (Report) | Trạng thái Hóa đơn |
| :--- | :--- | :--- | :--- | :--- |
| **Tạo hóa đơn** | Chưa sinh ra giao dịch | Không đổi | Không đổi | `Pending` (Chờ trả) |
| **Thanh toán** | `Expense` (Chi tiêu) | Giảm (-) | **Tính** vào Chi tiêu | `Paid` (Đã trả) |

**Logic Code:**
1.  Hóa đơn bản chất là một "Template" (Mẫu) giao dịch.
2.  Khi user bấm "Pay" trên hóa đơn -> Hệ thống sẽ `INSERT` một dòng vào bảng `transactions` (`Type = Expense`, `Category = Điện/Nước...`).
3.  Đồng thời update bảng `bills` set `next_due_date` sang kỳ sau.

---

## 4. Tổng Hợp Mô Hình Dòng Tiền (Data Flow)

Để dễ hình dung khi viết hàm tính toán số dư (`getBalance`) và báo cáo (`getReport`):

### A. Tính Số Dư Ví (Wallet Balance)
Sử dụng công thức tổng quát:

$$
Balance = \sum(Income) - \sum(Expense) + \sum(Transfer_{In}) - \sum(Transfer_{Out})
$$

*(Bao gồm cả tiền đi vay và cho vay)*

### B. Tính Tổng Chi Tiêu (Total Expense Report)
Chỉ tính chi phí thực tế mất đi:

$$
TotalExpense = \sum(Expense_{thường}) + \sum(Lãi_{trả\_cho\_khoản\_vay})
$$

*(**KHÔNG** bao gồm tiền Gốc trả nợ, **KHÔNG** bao gồm tiền gửi tiết kiệm)*

### C. Tính Tổng Thu Nhập (Total Income Report)
Chỉ tính thu nhập thực tế sinh ra:

$$
TotalIncome = \sum(Income_{thường}) + \sum(Lãi_{thu\_từ\_cho\_vay}) + \sum(Lãi_{tiết\_kiệm})
$$

*(**KHÔNG** bao gồm tiền đi vay được, **KHÔNG** bao gồm tiền thu hồi nợ gốc)*

---

## 5. Ví Dụ Minh Họa (Use Case)

**Kịch bản:**

1.  **A có:** 10 triệu trong ví.
2.  **Đi vay B:** 5 triệu.
    *   *Ví A:* 15 triệu. (Thu nhập vẫn là 0).
3.  **Cho C vay:** 2 triệu.
    *   *Ví A:* 13 triệu. (Chi tiêu vẫn là 0).
4.  **Trả nợ B:** 1.1 triệu (1tr Gốc + 100k Lãi).
    *   *Ví A:* 11.9 triệu.
    *   *Chi tiêu:* 100k (Chỉ tính lãi).
5.  **Thu nợ C:** 2.2 triệu (2tr Gốc + 200k Lãi).
    *   *Ví A:* 14.1 triệu.
    *   *Thu nhập:* 200k (Chỉ tính lãi).

**Kết quả cuối cùng:**
*   **Ví:** `14.1 triệu`.
*   **Báo cáo:** Lãi ròng (`Income` - `Expense`) = `200k` - `100k` = **+100k**.

---
*Áp dụng đúng logic này vào các hàm trong Repository của `plan_v3.md` để đảm bảo tính chính xác về mặt tài chính.*