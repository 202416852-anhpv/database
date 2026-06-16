-- ============================================================
-- File: ComplexFunctions.sql
-- 3 chức năng phức tạp (kiểm tra + tính toán + thay đổi dữ liệu)
-- ============================================================

-- -------------------------------------------------------
-- 1. Thanh toán hóa đơn
--    Tính lại phí dịch vụ, phí thuốc, cập nhật tổng tiền
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION process_payment(p_invoice_id INT)
RETURNS TEXT
LANGUAGE plpgsql AS $$
DECLARE
    v_appointment_id INT;
    v_current_status payment_status;
    v_total_service NUMERIC(15,2) := 0;
    v_total_prescription NUMERIC(15,2) := 0;
BEGIN
    -- Kiểm tra hóa đơn tồn tại và chưa thanh toán
    SELECT appointment_id, payment_status
    INTO v_appointment_id, v_current_status
    FROM invoice
    WHERE invoice_id = p_invoice_id;

    IF NOT FOUND THEN
        RETURN 'ERROR: Hóa đơn không tồn tại';
    END IF;

    IF v_current_status = 'paid' THEN
        RETURN 'ERROR: Hóa đơn đã được thanh toán';
    END IF;

    -- Tính tổng phí dịch vụ
    SELECT COALESCE(SUM(s.unit_price * aps.quantity), 0)
    INTO v_total_service
    FROM appointment_service aps
    JOIN service s ON aps.service_id = s.service_id
    WHERE aps.appointment_id = v_appointment_id;

    -- Tính tổng phí thuốc
    SELECT COALESCE(SUM(ms.unit_price * pd.quantity), 0)
    INTO v_total_prescription
    FROM prescription pr
    JOIN prescription_detail pd ON pr.prescription_id = pd.prescription_id
    JOIN medical_supply ms ON pd.supply_id = ms.supply_id
    WHERE pr.appointment_id = v_appointment_id;

    -- Cập nhật hóa đơn
    UPDATE invoice
    SET total_service_fee = v_total_service,
        total_prescription_fee = v_total_prescription,
        final_amount = v_total_service + v_total_prescription,
        payment_status = 'paid'
    WHERE invoice_id = p_invoice_id;

    RETURN 'OK: Thanh toán thành công. Tổng tiền: '
           || (v_total_service + v_total_prescription);
END;
$$;

-- -------------------------------------------------------
-- 2. Đặt lịch hẹn mới
--    Kiểm tra tồn tại bệnh nhân/bác sĩ, trùng lịch,
--    tự động tạo hóa đơn
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION book_appointment(
    p_patient_id INT,
    p_doctor_id INT,
    p_location_id VARCHAR(50),
    p_time TIMESTAMP,
    p_symptoms TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql AS $$
DECLARE
    v_new_id INT;
    v_patient_exists INT;
    v_doctor_exists INT;
    v_location_exists INT;
    v_conflict_count INT;
BEGIN
    -- Kiểm tra bệnh nhân
    SELECT COUNT(*) INTO v_patient_exists
    FROM patient WHERE patient_id = p_patient_id;

    IF v_patient_exists = 0 THEN
        RETURN 'ERROR: Bệnh nhân không tồn tại';
    END IF;

    -- Kiểm tra bác sĩ
    SELECT COUNT(*) INTO v_doctor_exists
    FROM employee
    WHERE employee_id = p_doctor_id AND title = 'doctor';

    IF v_doctor_exists = 0 THEN
        RETURN 'ERROR: Bác sĩ không tồn tại';
    END IF;

    -- Kiểm tra phòng
    SELECT COUNT(*) INTO v_location_exists
    FROM location WHERE location_id = p_location_id;

    IF v_location_exists = 0 THEN
        RETURN 'ERROR: Phòng khám không tồn tại';
    END IF;

    -- Kiểm tra trùng lịch bác sĩ (cùng ngày, lệch tối đa 1 tiếng)
    SELECT COUNT(*) INTO v_conflict_count
    FROM appointment
    WHERE doctor_id = p_doctor_id
      AND appointment_time BETWEEN p_time - INTERVAL '1 hour'
                               AND p_time + INTERVAL '1 hour'
      AND status != 'cancelled';

    IF v_conflict_count > 0 THEN
        RETURN 'ERROR: Bác sĩ đã có lịch hẹn trong khung giờ này ±1 tiếng';
    END IF;

    -- Tạo lịch hẹn
    INSERT INTO appointment (patient_id, doctor_id, location_id, appointment_time, symptoms)
    VALUES (p_patient_id, p_doctor_id, p_location_id, p_time, p_symptoms)
    RETURNING appointment_id INTO v_new_id;

    -- Tự động tạo hóa đơn
    INSERT INTO invoice (appointment_id)
    VALUES (v_new_id);

    RETURN 'OK: Đặt lịch thành công. Mã lịch hẹn: ' || v_new_id;
END;
$$;

-- -------------------------------------------------------
-- 3. Báo cáo doanh thu theo ngày và theo khoa
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_revenue_report(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE(
    report_date DATE,
    department_name VARCHAR(100),
    patient_count BIGINT,
    appointment_count BIGINT,
    total_service_fee NUMERIC(15,2),
    total_prescription_fee NUMERIC(15,2),
    total_revenue NUMERIC(15,2)
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT DATE(a.appointment_time)::DATE,
           d.department_name,
           COUNT(DISTINCT a.patient_id)::BIGINT,
           COUNT(DISTINCT a.appointment_id)::BIGINT,
           COALESCE(SUM(i.total_service_fee), 0.00),
           COALESCE(SUM(i.total_prescription_fee), 0.00),
           COALESCE(SUM(i.final_amount), 0.00)
    FROM appointment a
    JOIN employee e ON a.doctor_id = e.employee_id
    JOIN department d ON e.department_id = d.department_id
    LEFT JOIN invoice i ON a.appointment_id = i.appointment_id
    WHERE a.appointment_time >= p_start_date
      AND a.appointment_time < p_end_date + INTERVAL '1 day'
      AND i.payment_status = 'paid'
    GROUP BY DATE(a.appointment_time), d.department_name
    ORDER BY DATE(a.appointment_time), d.department_name;
END;
$$;
