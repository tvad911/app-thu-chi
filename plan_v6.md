# Plan V6 — Balance Adjustment & E-Wallet Support

## Bối cảnh

Trong thực tế, việc quản lý tài chính không phải lúc nào cũng diễn ra theo thời gian thực (Real-time). Có **3 trường hợp phổ biến** khiến logic cũ (*Tạo nợ = Trừ tiền ví*) bị sai:

1. **Nợ cũ:** Bạn cho bạn bè vay từ tháng trước, giờ mới cài App để nhập lại.
2. **Nợ phi tiền mặt:** Bạn bán chiếc xe cũ cho người ta, họ nợ tiền bạn (Tài sản xe mất đi, khoản phải thu tăng lên, tiền mặt trong ví không đổi).
3. **Tiết kiệm có sẵn:** Bạn đã có sổ tiết kiệm 100 triệu từ lâu, giờ chỉ muốn khai báo vào App để theo dõi tổng tài sản.

> [!IMPORTANT]
> Giải pháp: Cập nhật logic để xử lý vấn đề **"Cân bằng số dư"** và thêm **Ví điện tử**.

---

## 1. Cập nhật Logic Vay & Cho Vay (Debts)

Thay vì mặc định trừ tiền, thêm một **tùy chọn (Option)** khi tạo khoản nợ.

### Quy trình nghiệp vụ mới

Khi User tạo một khoản nợ mới (Vay hoặc Cho vay), giao diện sẽ có thêm một **Switch/Checkbox**: *"Ghi nhận giao dịch vào Ví?"* (`Create Transaction?`).

#### Trường hợp A: CÓ (Mặc định)

- **Ngữ cảnh:** Vừa rút ví đưa tiền cho bạn vay ngay lúc này.
- **Hành động hệ thống:**
  1. Tạo record trong bảng `debts`.
  2. Tạo record trong bảng `transactions` (Loại `Transfer`/`Expenditure`).
  3. Trừ/Cộng tiền trong Ví tương ứng.

#### Trường hợp B: KHÔNG (Chỉ ghi sổ)

- **Ngữ cảnh:** Nhập lại nợ cũ, hoặc bán đồ lấy nợ.
- **Hành động hệ thống:**
  1. Chỉ tạo record trong bảng `debts`.
  2. **KHÔNG** tạo Transaction.
  3. **KHÔNG** thay đổi số dư bất kỳ ví nào.

> [!NOTE]
> **Kết quả:** "Tổng tài sản" (Net Worth) sẽ thay đổi (do cộng thêm khoản phải thu/phải trả), nhưng "Tiền mặt khả dụng" (Cash Balance) giữ nguyên → Đúng chuẩn kế toán.

---

## 2. Cập nhật Logic Tiết Kiệm (Savings)

Tương tự như nợ, sổ tiết kiệm cũng có **2 trạng thái** nhập liệu.

### Trạng thái 1: Khởi tạo (Initial Balance)

- Khi tạo một ví Tiết kiệm mới, cho phép nhập **"Số dư ban đầu"**.
- Số tiền này sẽ được cộng thẳng vào **Tổng tài sản** mà không cần trừ từ ví nào cả (coi như tài sản mang từ quá khứ tới).

### Trạng thái 2: Gửi thêm (Top-up)

Khi bấm nút **"Nạp tiền/Gửi thêm"** vào sổ tiết kiệm, hỏi user: *"Nguồn tiền từ đâu?"*

| Lựa chọn | Hành động | Ví dụ |
|---|---|---|
| Chọn **Ví A** | Tạo giao dịch `Transfer` (Ví A giảm → Tiết kiệm tăng) | Rút tiền gửi tiết kiệm |
| Chọn **"Nguồn ngoài"** (`Income`) | Tiết kiệm tăng, Ví A không đổi | Được thưởng chuyển thẳng vào sổ tiết kiệm |

---

## 3. Thêm Ví Điện Tử (E-Wallet)

### Database

Trong bảng `accounts`, cột `type` thêm giá trị `E_WALLET`:

```
Enum: CASH, BANK, CREDIT, SAVING, E_WALLET
```

### UI/UX

- Khi chọn loại `E_WALLET`, App gợi ý các icon phổ biến: **Momo**, **ZaloPay**, **ShopeePay**, **ViettelMoney**, **Apple Pay**.
- Tính chất của Ví điện tử **giống hệt Ví ngân hàng** (có thể Transfer, có thể Thu/Chi).

---

## 4. Chi tiết kỹ thuật

### 4.1. Cập nhật Database Schema

#### Table `accounts`

- Update cột `type`: thêm giá trị `E_WALLET`.
- Enum: `CASH`, `BANK`, `CREDIT`, `SAVING`, `E_WALLET`.

#### Table `debts`

- Không cần sửa bảng, chỉ sửa **logic code**.

### 4.2. Cập nhật Logic Code (Pseudo-code)

#### A. Hàm tạo khoản nợ (`createDebt`)

```dart
Future<void> createDebt({
  required Debt debt,
  required bool createTransaction, // New flag
  int? walletId, // Required if createTransaction = true
}) async {
  // 1. Always create debt record
  int debtId = await db.insertDebt(debt);

  // 2. Only affect wallet if user requests
  if (createTransaction && walletId != null) {
    await createTransaction(
      Transaction(
        amount: debt.totalAmount,
        accountId: walletId,
        debtId: debtId,
        type: debt.type == DebtType.LEND
            ? TransactionType.OUT
            : TransactionType.IN,
        // ...
      )
    );
    // Wallet balance update handled inside createTransaction
  }
}
```

#### B. Hàm tạo ví mới (`createAccount`)

```dart
Future<void> createAccount({
  required String name,
  required AccountType type,
  required double initialBalance, // Initial balance
}) async {
  // Insert to DB. initialBalance is the starting balance.
  // No transaction created — this is a balance adjustment.
  await db.into(accounts).insert(
    AccountsCompanion(
      name: Value(name),
      type: Value(type),
      balance: Value(initialBalance),
      // ...
    )
  );
}
```

---

## Tổng kết thay đổi

Với logic mới này, ứng dụng sẽ linh hoạt hơn:

- ✅ Người dùng mới cài app **không bị "âm tiền" vô lý** khi nhập lại các khoản nợ cũ.
- ✅ Quản lý được các nguồn tiền **"từ ngoài hệ thống"** (không qua ví chính).
- ✅ Có thêm **Ví điện tử** (Momo/ZaloPay) — phương thức thanh toán phổ biến hiện nay.

> [!TIP]
> Đồng thời cập nhật lịch sử giao dịch, logs: các từ tiếng Việt nên chuyển sang tiếng Anh.