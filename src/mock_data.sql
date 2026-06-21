-- ============================================================
-- Mock data — realistic hospital scale
-- 20 depts, 200 employees, 1000 patients, 5000 appointments
-- ============================================================

-- 1. patient (1000)
INSERT INTO patient (full_name, date_of_birth, gender, phone_number, address)
SELECT 'Patient_' || i,
       date '1950-01-01' + (random() * 20000)::int,
       CASE WHEN random() < 0.5 THEN 'M'::gender_value ELSE 'F'::gender_value END,
       lpad((floor(random() * 10000000000))::bigint::text, 10, '0'),
       'Addr ' || i || ', City ' || ((i - 1) % 50 + 1)
FROM generate_series(1, 1000) AS s(i);

-- 2. medical_supply (200)
INSERT INTO medical_supply (supply_name, unit_price, quantity_in_stock)
SELECT 'Supply_' || i,
       (random() * 500 + 5)::int,
       (random() * 1000)::int
FROM generate_series(1, 200) AS s(i);

-- 3. department (20) — manager_id set later
INSERT INTO department (department_name)
SELECT 'Dept_' || i
FROM generate_series(1, 20) AS s(i);

-- 4. employee (200) — 40 doctors, 80 nurses, 20 pharmacists, 30 receptionists, 30 accountants
INSERT INTO employee (department_id, full_name, phone_number, email, title)
SELECT (random() * 19 + 1)::int,
       'Emp_' || i,
       lpad((floor(random() * 10000000000))::bigint::text, 10, '0'),
       'emp' || i || '@hosp.com',
       CASE
           WHEN i <= 40 THEN 'doctor'::employee_title
           WHEN i <= 120 THEN 'nurse'
           WHEN i <= 140 THEN 'pharmacist'
           WHEN i <= 170 THEN 'receptionist'
           ELSE 'accountant'
           END
FROM generate_series(1, 200) AS s(i);

-- 5. department managers (circular ref: dept?emp, resolved by ordering inserts, no FK bypass needed)
UPDATE department d
SET manager_id = (SELECT employee_id
                  FROM employee e
                  WHERE e.department_id = d.department_id
                    AND e.title = 'doctor'
                  ORDER BY random()
                  LIMIT 1)
WHERE d.department_name like 'D*';

-- 6. location (200) — A-T prefixes, 10 rooms per dept
INSERT INTO location (location_id, department_id, employee_id)
SELECT chr(65 + ((i - 1) / 10)::int) || '-' || lpad(((i - 1) % 10 + 1)::text, 3, '0'),
       ((i - 1) / 10)::int + 1,
       (random() * 199 + 1)::int
FROM generate_series(1, 200) AS s(i);

-- 7. service (100) — random locations from the A-T set
INSERT INTO service (service_name, unit_price, location_id)
SELECT 'Svc_' || i,
       (random() * 1000 + 10)::int,
       chr(65 + floor(random() * 20)::int) || '-' || lpad((floor(random() * 10)::int + 1)::text, 3, '0')
FROM generate_series(1, 100) AS s(i);

-- 8. appointment (5000) — doctor_id only from doctors
WITH doc AS (SELECT array_agg(employee_id) AS ids FROM employee WHERE title = 'doctor')
INSERT
INTO appointment (patient_id, doctor_id, location_id, appointment_time, status, payment_status, symptoms, diagnosis,
                  doctor_notes)
SELECT (random() * 999 + 1)::int,
       doc.ids[1 + floor(random() * array_length(doc.ids, 1))::int],
       chr(65 + floor(random() * 20)::int) || '-' || lpad((floor(random() * 10)::int + 1)::text, 3, '0'),
       date '2024-06-01' + (random() * 730)::int + time '08:00:00' + random() * interval '10 hours',
       (ARRAY ['waiting'::appointment_status, 'ongoing', 'finished', 'cancelled'])[floor(random() * 4 + 1)],
       random() < 0.3,
       'Sx ' || i,
       'Dx ' || i,
       'Notes ' || i
FROM generate_series(1, 5000) AS s(i),
     doc;

-- 9. appointment_service (10000, 2 per appointment)
INSERT INTO appointment_service (appointment_id, service_id, quantity, service_result)
SELECT (i - 1) / 2 + 1,
       ((i - 1) % 100) + 1,
       (random() * 5 + 1)::int,
       'Result'
FROM generate_series(1, 10000) AS s(i);

-- 10. appointment_supply (7500, ~1-2 per appointment)
INSERT INTO appointment_supply (appointment_id, supply_id, quantity, instruction)
SELECT (i - 1) / 2 + 1,
       ((i - 1) % 200) + 1,
       (random() * 5 + 1)::int,
       'Instruction'
FROM generate_series(1, 7500) AS s(i);
