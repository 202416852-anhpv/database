create type employee_title as enum ('doctor', 'nurse', 'pharmacist', 'receptionist', 'accountant');
create type appointment_status as enum ('waiting', 'ongoing', 'finished', 'cancelled');
create type payment_status as enum ('unpaid', 'paid');

-- 1. patient
create table patient (
    patient_id serial primary key,
    full_name varchar(100) not null,
    date_of_birth date,
    gender varchar(10),
    phone_number varchar(20),
    _address varchar(100),
    created_at timestamp default current_timestamp
);

-- 2. employee
create table employee (
    employee_id serial primary key,
    department_id int, -- FK
    full_name varchar(100) not null,
    phone_number varchar(20),
    email varchar(100),
    title employee_title not null,
    created_at timestamp default current_timestamp
);

-- 3. appointment
create table appointment (
    appointment_id serial primary key,
    patient_id int not null, -- FK
    doctor_id int not null, -- FK
    location_id varchar(20), -- FK
    appointment_time timestamp not null, -- Use timestamp to store both date and time
    status appointment_status default 'waiting',
    symptoms varchar(200),
    diagnosis varchar(200),
    doctor_notes varchar(200),
    created_at timestamp default current_timestamp
);

-- 4. department
create table department (
    department_id serial primary key,
    department_name varchar(100) not null,
    manager_id int -- FK
);

-- 5. location
create table location (
    location_id varchar(20) primary key,
    department_id int, -- FK
    employee_id int -- FK
);

-- 6. service
create table service (
    service_id serial primary key,
    service_name varchar(100) not null,
    unit_price numeric(20, 2) not null check (unit_price >= 0),
    location_id varchar(20) -- FK
);

-- 7. appointment_service
create table appointment_service (
    appointment_service_id serial primary key,
    appointment_id int not null, -- FK
    service_id int not null, -- FK
    quantity int default 1 check (quantity > 0),
    service_result varchar(200)
);

-- 8. medical_supply
create table medical_supply (
    supply_id serial primary key,
    supply_name varchar(150) not null,
    unit_price numeric(20, 2) not null check (unit_price >= 0),
    quantity_in_stock int default 0 check (quantity_in_stock >= 0)
);

-- 9. prescription
create table prescription (
    prescription_id serial primary key,
    appointment_id int not null, -- FK
    created_at timestamp default current_timestamp
);

-- 10. prescription_detail
create table prescription_detail (
    prescription_detail_id serial primary key,
    prescription_id int not null, -- FK
    supply_id int not null, -- FK
    quantity int not null check (quantity > 0),
    instruction varchar(200)
);

-- 11. invoice
create table invoice (
    invoice_id serial primary key,
    appointment_id int not null, -- FK
    total_service_fee numeric(20, 2) default 0.00 check (total_service_fee >= 0),
    total_prescription_fee numeric(20, 2) default 0.00 check (total_prescription_fee >= 0),
    final_amount numeric(20, 2) default 0.00 check (final_amount >= 0),
    payment_status payment_status default 'unpaid',
    created_at timestamp default current_timestamp
);

-- department references employee (head of department)
alter table department 
add constraint fk_department_manager foreign key (manager_id) references employee(employee_id) on delete set null;

-- employee references department
alter table employee 
add constraint fk_employee_department foreign key (department_id) references department(department_id) on delete set null;

-- location references department and employee
alter table location 
add constraint fk_location_department foreign key (department_id) references department(department_id) on delete cascade,
add constraint fk_location_employee foreign key (employee_id) references employee(employee_id) on delete set null;

-- appointment references patient, employee(doctor), and location
alter table appointment 
add constraint fk_appointment_patient foreign key (patient_id) references patient(patient_id) on delete cascade,
add constraint fk_appointment_doctor foreign key (doctor_id) references employee(employee_id) on delete restrict,
add constraint fk_appointment_location foreign key (location_id) references location(location_id) on delete set null;

-- service references location
alter table service 
add constraint fk_service_location foreign key (location_id) references location(location_id) on delete set null;

-- appointment_service references appointment and service
alter table appointment_service 
add constraint fk_app_service_appointment foreign key (appointment_id) references appointment(appointment_id) on delete cascade,
add constraint fk_app_service_service foreign key (service_id) references service(service_id) on delete restrict;

-- prescription references appointment
alter table prescription 
add constraint fk_prescription_appointment foreign key (appointment_id) references appointment(appointment_id) on delete cascade;

-- prescription_detail references prescription and medical_supply
alter table prescription_detail 
add constraint fk_predetail_prescription foreign key (prescription_id) references prescription(prescription_id) on delete cascade,
add constraint fk_predetail_supply foreign key (supply_id) references medical_supply(supply_id) on delete restrict;

-- invoice references appointment
alter table invoice 
add constraint fk_invoice_appointment foreign key (appointment_id) references appointment(appointment_id) on delete cascade;

-- indexes for foreign key columns
create index idx_appointment_patient on appointment(patient_id);
create index idx_appointment_doctor on appointment(doctor_id);
create index idx_appointment_location on appointment(location_id);
create index idx_appointment_time on appointment(appointment_time);
create index idx_employee_department on employee(department_id);
create index idx_app_service_appointment on appointment_service(appointment_id);
create index idx_app_service_service on appointment_service(service_id);
create index idx_prescription_appointment on prescription(appointment_id);
create index idx_predetail_prescription on prescription_detail(prescription_id);
create index idx_predetail_supply on prescription_detail(supply_id);
create index idx_invoice_appointment on invoice(appointment_id);


