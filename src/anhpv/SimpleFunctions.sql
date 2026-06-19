-- ============================================================
-- File: SimpleFunctions.sql
-- 3 chức năng đơn giản (chỉ SELECT, không thay đổi dữ liệu)
-- ============================================================

-- -------------------------------------------------------
-- 1. Xem danh sách lịch hẹn + chẩn đoán của bệnh nhân
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_patient_appointments(p_patient_id INT)
RETURNS TABLE(
    appointment_id INT,
    doctor_name VARCHAR(100),
    appointment_time TIMESTAMP,
    status appointment_status,
    diagnosis TEXT,
    symptoms TEXT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT a.appointment_id,
           e.full_name,
           a.appointment_time,
           a.status,
           a.diagnosis,
           a.symptoms
    FROM appointment a
    JOIN employee e ON a.doctor_id = e.employee_id
    WHERE a.patient_id = p_patient_id
    ORDER BY a.appointment_time DESC;
END;
$$;

-- -------------------------------------------------------
-- 2. Xem danh sách nhân viên + chức danh trong một khoa
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_employees_by_department(p_department_id INT)
RETURNS TABLE(
    employee_id INT,
    full_name VARCHAR(100),
    title employee_title,
    phone_number VARCHAR(20),
    email VARCHAR(100)
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT e.employee_id,
           e.full_name,
           e.title,
           e.phone_number,
           e.email
    FROM employee e
    WHERE e.department_id = p_department_id
    ORDER BY e.title, e.full_name;
END;
$$;

-- -------------------------------------------------------
-- 3. Xem chi tiết 1 lịch hẹn
--    (bệnh nhân, bác sĩ, dịch vụ, đơn thuốc, hóa đơn)
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_appointment_details(p_appointment_id INT)
RETURNS TABLE(
    patient_name VARCHAR(100),
    doctor_name VARCHAR(100),
    appointment_time TIMESTAMP,
    status appointment_status,
    diagnosis TEXT,
    services TEXT,
    medications TEXT,
    total_service_fee NUMERIC(20,2),
    total_prescription_fee NUMERIC(20,2),
    final_amount NUMERIC(20,2)
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT p.full_name,
           e.full_name,
           a.appointment_time,
           a.status,
           a.diagnosis,
           STRING_AGG(DISTINCT s.service_name || ' (x' || aps.quantity || ')', ', '),
           STRING_AGG(DISTINCT ms.supply_name || ' (x' || pd.quantity || ')', ', '),
           COALESCE(i.total_service_fee, 0.00),
           COALESCE(i.total_prescription_fee, 0.00),
           COALESCE(i.final_amount, 0.00)
    FROM appointment a
    JOIN patient p ON a.patient_id = p.patient_id
    JOIN employee e ON a.doctor_id = e.employee_id
    LEFT JOIN appointment_service aps ON a.appointment_id = aps.appointment_id
    LEFT JOIN service s ON aps.service_id = s.service_id
    LEFT JOIN prescription pr ON a.appointment_id = pr.appointment_id
    LEFT JOIN prescription_detail pd ON pr.prescription_id = pd.prescription_id
    LEFT JOIN medical_supply ms ON pd.supply_id = ms.supply_id
    LEFT JOIN invoice i ON a.appointment_id = i.appointment_id
    WHERE a.appointment_id = p_appointment_id
    GROUP BY p.full_name, e.full_name, a.appointment_time,
             a.status, a.diagnosis, i.total_service_fee,
             i.total_prescription_fee, i.final_amount;
END;
$$;
