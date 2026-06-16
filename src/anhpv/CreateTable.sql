CREATE TYPE employee_title AS ENUM ('doctor', 'nurse', 'pharmacist', 'receptionist', 'accountant');
CREATE TYPE appointment_status AS ENUM ('waiting', 'ongoing', 'finished');
CREATE TYPE payment_status AS ENUM ('unpaid', 'paid');

-- Table: patient
CREATE TABLE patient (
    patient_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    gender VARCHAR(10),
    phone_number VARCHAR(15),
    address VARCHAR(100)
);

-- Table: department
CREATE TABLE department (
    department_id SERIAL PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    manager_id INT, -- FK sẽ cấu hình ở cuối
    location VARCHAR(255)
);

-- Table: employee
CREATE TABLE employee (
    employee_id SERIAL PRIMARY KEY,
    department_id INT, -- FK sẽ cấu hình ở cuối
    full_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(15),
    email VARCHAR(100),
    title employee_title NOT NULL
);

-- Table: location
CREATE TABLE location (
    location_id VARCHAR(50) PRIMARY KEY, -- Lấy trực tiếp số phòng (VD: D9-501)
    department_id INT, -- FK sẽ cấu hình ở cuối
    employee_id INT -- FK sẽ cấu hình ở cuối
);

-- Table: appointment
CREATE TABLE appointment (
    appointment_id SERIAL PRIMARY KEY,
    patient_id INT NOT NULL, -- FK sẽ cấu hình ở cuối
    doctor_id INT NOT NULL, -- FK sẽ cấu hình ở cuối
    location_id VARCHAR(50), -- FK sẽ cấu hình ở cuối
    appointment_time TIMESTAMP NOT NULL, -- Thay DATE bằng TIMESTAMP để lưu cả giờ khám
    status appointment_status DEFAULT 'waiting',
    symptoms TEXT,
    diagnosis TEXT,
    doctor_notes TEXT
);

-- Table: service
CREATE TABLE service (
    service_id SERIAL PRIMARY KEY,
    service_name VARCHAR(150) NOT NULL,
    unit_price NUMERIC(15, 2) NOT NULL, -- Dùng NUMERIC cho tiền tệ (VND)
    location_id VARCHAR(50) -- FK sẽ cấu hình ở cuối
);

-- Table: appointment_service
CREATE TABLE appointment_service (
    appointment_service_id SERIAL PRIMARY KEY,
    appointment_id INT NOT NULL, -- FK sẽ cấu hình ở cuối
    service_id INT NOT NULL, -- FK sẽ cấu hình ở cuối
    quantity INT DEFAULT 1,
    service_result TEXT
);

-- Table: medical_supply
CREATE TABLE medical_supply (
    supply_id SERIAL PRIMARY KEY,
    supply_name VARCHAR(150) NOT NULL,
    unit_price NUMERIC(15, 2) NOT NULL,
    quantity_in_stock INT DEFAULT 0
);

-- Table: prescription
CREATE TABLE prescription (
    prescription_id SERIAL PRIMARY KEY,
    appointment_id INT NOT NULL -- FK sẽ cấu hình ở cuối
);

-- Table: prescription_detail
CREATE TABLE prescription_detail (
    prescription_detail_id SERIAL PRIMARY KEY,
    prescription_id INT NOT NULL, -- FK sẽ cấu hình ở cuối
    supply_id INT NOT NULL, -- FK sẽ cấu hình ở cuối
    quantity INT NOT NULL,
    instruction TEXT
);

-- Table: invoice
CREATE TABLE invoice (
    invoice_id SERIAL PRIMARY KEY,
    appointment_id INT NOT NULL, -- FK sẽ cấu hình ở cuối
    total_service_fee NUMERIC(15, 2) DEFAULT 0.00,
    total_prescription_fee NUMERIC(15, 2) DEFAULT 0.00,
    final_amount NUMERIC(15, 2) DEFAULT 0.00,
    payment_status payment_status DEFAULT 'unpaid'
);

-- -----------------------------------------------------
-- FOREIGN KEY CONSTRAINTS (Khóa ngoại)
-- -----------------------------------------------------

-- Bảng department liên kết với employee (Trưởng khoa)
ALTER TABLE department 
ADD CONSTRAINT fk_department_manager FOREIGN KEY (manager_id) REFERENCES employee(employee_id) ON DELETE SET NULL;

-- Bảng employee liên kết với department
ALTER TABLE employee 
ADD CONSTRAINT fk_employee_department FOREIGN KEY (department_id) REFERENCES department(department_id) ON DELETE SET NULL;

-- Bảng location liên kết với department và employee
ALTER TABLE location 
ADD CONSTRAINT fk_location_department FOREIGN KEY (department_id) REFERENCES department(department_id) ON DELETE CASCADE,
ADD CONSTRAINT fk_location_employee FOREIGN KEY (employee_id) REFERENCES employee(employee_id) ON DELETE SET NULL;

-- Bảng appointment liên kết với patient, employee(doctor), và location
ALTER TABLE appointment 
ADD CONSTRAINT fk_appointment_patient FOREIGN KEY (patient_id) REFERENCES patient(patient_id) ON DELETE CASCADE,
ADD CONSTRAINT fk_appointment_doctor FOREIGN KEY (doctor_id) REFERENCES employee(employee_id) ON DELETE RESTRICT,
ADD CONSTRAINT fk_appointment_location FOREIGN KEY (location_id) REFERENCES location(location_id) ON DELETE SET NULL;

-- Bảng service liên kết với location
ALTER TABLE service 
ADD CONSTRAINT fk_service_location FOREIGN KEY (location_id) REFERENCES location(location_id) ON DELETE SET NULL;

-- Bảng appointment_service liên kết với appointment và service
ALTER TABLE appointment_service 
ADD CONSTRAINT fk_app_service_appointment FOREIGN KEY (appointment_id) REFERENCES appointment(appointment_id) ON DELETE CASCADE,
ADD CONSTRAINT fk_app_service_service FOREIGN KEY (service_id) REFERENCES service(service_id) ON DELETE RESTRICT;

-- Bảng prescription liên kết với appointment
ALTER TABLE prescription 
ADD CONSTRAINT fk_prescription_appointment FOREIGN KEY (appointment_id) REFERENCES appointment(appointment_id) ON DELETE CASCADE;

-- Bảng prescription_detail liên kết với prescription và medical_supply
ALTER TABLE prescription_detail 
ADD CONSTRAINT fk_predetail_prescription FOREIGN KEY (prescription_id) REFERENCES prescription(prescription_id) ON DELETE CASCADE,
ADD CONSTRAINT fk_predetail_supply FOREIGN KEY (supply_id) REFERENCES medical_supply(supply_id) ON DELETE RESTRICT;

-- Bảng invoice liên kết với appointment
ALTER TABLE invoice 
ADD CONSTRAINT fk_invoice_appointment FOREIGN KEY (appointment_id) REFERENCES appointment(appointment_id) ON DELETE CASCADE;


-- -----------------------------------------------------
-- CHECK CONSTRAINTS (Ràng buộc kiểm tra dữ liệu lớn hơn 0)
-- -----------------------------------------------------

-- Kiểm tra đơn giá dịch vụ và số lượng đi kèm
ALTER TABLE service ADD CONSTRAINT chk_service_price CHECK (unit_price >= 0);
ALTER TABLE appointment_service ADD CONSTRAINT chk_app_service_qty CHECK (quantity > 0);

-- Kiểm tra đơn giá và số lượng tồn kho của dược phẩm/vật tư
ALTER TABLE medical_supply 
ADD CONSTRAINT chk_supply_price CHECK (unit_price >= 0),
ADD CONSTRAINT chk_supply_stock CHECK (quantity_in_stock >= 0);

-- Kiểm tra số lượng thuốc trong đơn
ALTER TABLE prescription_detail ADD CONSTRAINT chk_prescription_qty CHECK (quantity > 0);

-- Kiểm tra số tiền trong hóa đơn không được âm
ALTER TABLE invoice 
ADD CONSTRAINT chk_invoice_service_fee CHECK (total_service_fee >= 0),
ADD CONSTRAINT chk_invoice_prescription_fee CHECK (total_prescription_fee >= 0),
ADD CONSTRAINT chk_invoice_final_amount CHECK (final_amount >= 0);