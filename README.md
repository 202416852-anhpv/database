# Hệ thống quản lý phòng khám

## Cấu trúc thư mục

```
src/anhpv/
├── create_table.sql         # Định nghĩa CSDL (bảng, khóa ngoại, check)
├── simple_functions.sql     # 3 tính năng đơn giản (SELECT)
└── complex_functions.sql    # 3 tính năng phức tạp (kiểm tra + tổng hợp)
```

## Thứ tự chạy

1. `create_table.sql`
2. `simple_functions.sql`
3. `complex_functions.sql`

---

## Phần 1 — Tính năng đơn giản (chỉ truy xuất)

### 1.1 `get_patient_appointments(p_patient_id INT)`

Xem danh sách lịch hẹn + chẩn đoán của một bệnh nhân.

| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `appointment_id` | `INT` | Mã lịch hẹn |
| `doctor_name` | `VARCHAR(100)` | Tên bác sĩ |
| `appointment_time` | `TIMESTAMP` | Thời gian hẹn |
| `status` | `appointment_status` | Trạng thái (waiting/ongoing/finished) |
| `diagnosis` | `TEXT` | Chẩn đoán |
| `symptoms` | `TEXT` | Triệu chứng |

```sql
SELECT * FROM get_patient_appointments(1);
```

### 1.2 `get_employees_by_department(p_department_id INT)`

Xem danh sách nhân viên + chức danh trong một khoa.

| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `employee_id` | `INT` | Mã nhân viên |
| `full_name` | `VARCHAR(100)` | Họ tên |
| `title` | `employee_title` | Chức danh |
| `phone_number` | `VARCHAR(15)` | Số điện thoại |
| `email` | `VARCHAR(100)` | Email |

```sql
SELECT * FROM get_employees_by_department(1);
```

### 1.3 `get_appointment_details(p_appointment_id INT)`

Xem toàn bộ chi tiết một lịch hẹn: bệnh nhân, bác sĩ, dịch vụ, đơn thuốc, hóa đơn.

| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `patient_name` | `VARCHAR(100)` | Tên bệnh nhân |
| `doctor_name` | `VARCHAR(100)` | Tên bác sĩ |
| `appointment_time` | `TIMESTAMP` | Thời gian |
| `status` | `appointment_status` | Trạng thái |
| `diagnosis` | `TEXT` | Chẩn đoán |
| `services` | `TEXT` | Danh sách dịch vụ (gộp chuỗi) |
| `medications` | `TEXT` | Danh sách thuốc (gộp chuỗi) |
| `total_service_fee` | `NUMERIC(15,2)` | Phí dịch vụ |
| `total_prescription_fee` | `NUMERIC(15,2)` | Phí thuốc |
| `final_amount` | `NUMERIC(15,2)` | Tổng tiền |

```sql
SELECT * FROM get_appointment_details(1);
```

---

## Phần 2 — Tính năng phức tạp (kiểm tra + tổng hợp + ghi dữ liệu)

### 2.1 `process_payment(p_invoice_id INT)` → `TEXT`

Thanh toán hóa đơn.

**Quy trình:**
1. Kiểm tra hóa đơn tồn tại — nếu không → `ERROR`
2. Kiểm tra `payment_status` — nếu đã `'paid'` → `ERROR`
3. Truy vấn `appointment_service × service.unit_price` → tính `total_service_fee`
4. Truy vấn `prescription_detail × medical_supply.unit_price` → tính `total_prescription_fee`
5. Cập nhật `invoice`: set `total_service_fee`, `total_prescription_fee`, `final_amount`, `payment_status = 'paid'`

```sql
SELECT process_payment(1);
-- Kết quả: OK: Thanh toán thành công. Tổng tiền: 500000.00
```

### 2.2 `book_appointment(p_patient_id INT, p_doctor_id INT, p_location_id VARCHAR(50), p_time TIMESTAMP, p_symptoms TEXT DEFAULT NULL)` → `TEXT`

Đặt lịch hẹn mới.

**Quy trình:**
1. Kiểm tra bệnh nhân tồn tại (bảng `patient`)
2. Kiểm tra bác sĩ tồn tại và có `title = 'doctor'`
3. Kiểm tra phòng khám tồn tại (bảng `location`)
4. Kiểm tra trùng lịch: bác sĩ đã có lịch hẹn khác trong ±1 tiếng, không tính lịch `'cancelled'` — nếu có → `ERROR`
5. INSERT `appointment` → lấy `appointment_id`
6. Tự động INSERT `invoice` tương ứng

```sql
SELECT book_appointment(
    1,               -- patient_id
    2,               -- doctor_id
    'D9-501',        -- location_id
    '2026-06-17 09:00:00'::TIMESTAMP,
    'Đau đầu, chóng mặt'  -- symptoms
);
-- Kết quả: OK: Đặt lịch thành công. Mã lịch hẹn: 5
```

### 2.3 `get_revenue_report(p_start_date DATE, p_end_date DATE)` → `TABLE`

Báo cáo doanh thu theo ngày và theo khoa — chỉ tính các hóa đơn đã thanh toán (`payment_status = 'paid'`).

| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `report_date` | `DATE` | Ngày |
| `department_name` | `VARCHAR(100)` | Tên khoa |
| `patient_count` | `BIGINT` | Số lượng bệnh nhân |
| `appointment_count` | `BIGINT` | Số lịch hẹn đã hoàn thành |
| `total_service_fee` | `NUMERIC(15,2)` | Tổng phí dịch vụ |
| `total_prescription_fee` | `NUMERIC(15,2)` | Tổng phí thuốc |
| `total_revenue` | `NUMERIC(15,2)` | Tổng doanh thu |

```sql
SELECT * FROM get_revenue_report('2026-06-01', '2026-06-30');
```
