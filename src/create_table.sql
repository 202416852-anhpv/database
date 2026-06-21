-- TYPES --
drop type gender_value,employee_title,appointment_status cascade;
create type gender_value as enum ('M', 'F');
create type employee_title as enum ('doctor', 'nurse', 'pharmacist', 'receptionist', 'accountant');
create type appointment_status as enum ('waiting', 'ongoing', 'finished', 'cancelled');
-----------

-- TABLES --
-- 1. patient: store information about patient
drop table if exists patient cascade;
create table patient
(
    patient_id    serial primary key,
    full_name     varchar(128) not null,
    date_of_birth date,
    gender        gender_value,
    phone_number  char(10),
    address       varchar(128),
    created_at    timestamp default current_timestamp,
    updated_at    timestamp default current_timestamp
);

-- 2. employee: store information of employee, both clinical and functional
drop table if exists employee cascade;
create table employee
(
    employee_id   serial primary key,
    department_id int, -- fk(department)
    full_name     varchar(128)   not null,
    phone_number  char(10),
    email         varchar(64),
    title         employee_title not null,
    created_at    timestamp default current_timestamp,
    updated_at    timestamp default current_timestamp
);

-- 3. department: store information of department of hospital
drop table if exists department cascade;
create table department
(
    department_id   serial primary key,
    department_name varchar(64) not null,
    manager_id      int, -- fk(employee)
    created_at      timestamp default current_timestamp,
    updated_at      timestamp default current_timestamp
);

-- 4. location: store functional, clinical, preclinical room of a department
drop table if exists location cascade;
create table location
(
    location_id   varchar(16) primary key,
    department_id int, -- fk(department)
    employee_id   int  -- fk(employee)
);

-- 5. service: store service that hospital provides
drop table if exists service cascade;
create table service
(
    service_id   serial primary key,
    service_name varchar(64) not null,
    unit_price   int         not null check (unit_price >= 0),
    location_id  varchar(16) -- fk(location)
);

-- 6. medical_supply
drop table if exists medical_supply cascade;
create table medical_supply
(
    supply_id         serial primary key,
    supply_name       varchar(128) not null,
    unit_price        int          not null check (unit_price >= 0),
    quantity_in_stock int default 0 check (quantity_in_stock >= 0)
);

-- 7. appointment
drop table if exists appointment cascade;
create table appointment
(
    appointment_id   serial primary key,
    patient_id       int,                -- fk(patient)
    doctor_id        int,                -- fk(employee)
    location_id      varchar(16),        -- fk(location)
    appointment_time timestamp not null, -- use timestamp to store both date and time
    status           appointment_status default 'waiting',
    payment_status   boolean            default false,
    symptoms         varchar(256),
    diagnosis        varchar(256),
    doctor_notes     varchar(256),
    created_at       timestamp          default current_timestamp,
    updated_at       timestamp          default current_timestamp
);

-- 8. appointment_service
drop table if exists appointment_service cascade;
create table appointment_service
(
    appointment_id int not null,             -- fk(appointment)
    service_id     int not null,             -- fk(service)
    primary key (appointment_id, service_id),-- pk(appointment_id, service_id)
    quantity       int default 1 check (quantity > 0),
    service_result varchar(256)
);

-- 9. appointment_supply
drop table if exists appointment_supply cascade;
create table appointment_supply
(
    appointment_id int not null,            -- fk(appointment)
    supply_id      int not null,            -- fk(medical_supply)
    primary key (appointment_id, supply_id),-- pk(appointment_id, supply_id)
    quantity       int default 1 check (quantity > 0),
    instruction    varchar(256)
);
------------

-- REFERENCES --
-- employee references department
alter table employee
    add constraint fk_emp_dept foreign key (department_id) references department on delete set null;

-- department references employee (head of department)
alter table department
    add constraint fk_dept_mgr foreign key (manager_id) references employee (employee_id) on delete set null;

-- location references department and employee
alter table location
    add constraint fk_loc_dept foreign key (department_id) references department on delete cascade,
    add constraint fk_loc_emp foreign key (employee_id) references employee on delete set null;

-- service references location
alter table service
    add constraint fk_serv_loc foreign key (location_id) references location on delete set null;

-- appointment references patient, employee(doctor), and location
alter table appointment
    add constraint fk_appt_pat foreign key (patient_id) references patient on delete cascade,
    add constraint fk_appt_dr foreign key (doctor_id) references employee (employee_id) on delete restrict,
    add constraint fk_appt_loc foreign key (location_id) references location on delete set null;

-- appointment_service references appointment and service
alter table appointment_service
    add constraint fk_appt_serv_appt foreign key (appointment_id) references appointment on delete cascade,
    add constraint fk_appt_serv_serv foreign key (service_id) references service on delete restrict;

-- appointment_supply references appointment and medical_supply
alter table appointment_supply
    add constraint fk_appt_sup_appt foreign key (appointment_id) references appointment on delete cascade,
    add constraint fk_appt_sup_sup foreign key (supply_id) references medical_supply on delete restrict;
----------------

-- INDEXES --
drop index if exists idx_emp_dept,idx_dept_mgr,idx_loc_dept,idx_loc_emp,idx_serv_loc,idx_appt_pat,idx_appt_dr,idx_appt_loc,idx_appt_serv_appt,idx_appt_serv_serv,idx_appt_sup_appt,idx_appt_sup_sup, idx_appt_time,idx_appt_status;
create index idx_emp_dept on employee (department_id);
create index idx_dept_mgr on department (manager_id);
create index idx_loc_dept on location (department_id);
create index idx_loc_emp on location (employee_id);
create index idx_serv_loc on service (location_id);
create index idx_appt_pat on appointment (patient_id);
create index idx_appt_dr on appointment (doctor_id);
create index idx_appt_loc on appointment (location_id);
create index idx_appt_serv_appt on appointment_service (appointment_id);
create index idx_appt_serv_serv on appointment_service (service_id);
create index idx_appt_sup_appt on appointment_supply (appointment_id);
create index idx_appt_sup_sup on appointment_supply (supply_id);

create index idx_appt_time on appointment (appointment_time);
create index idx_appt_status on appointment (status);
-------------

-- VIEWS --
drop view if exists appointment_invoice;
create view appointment_invoice as
select ie.*, supply_fee, ie.service_fee + supply_fee final_amount
from (select a.appointment_id, coalesce(sum(se.unit_price * ase.quantity), 0) service_fee
      from appointment a
               left join appointment_service ase on a.appointment_id = ase.appointment_id
               left join service se on ase.service_id = se.service_id
      group by a.appointment_id) ie
         left join (select a.appointment_id, coalesce(sum(su.unit_price * asu.quantity), 0) supply_fee
                    from appointment a
                             left join appointment_supply asu on a.appointment_id = asu.appointment_id
                             left join medical_supply su on asu.supply_id = su.supply_id
                    group by a.appointment_id) iu
                   on ie.appointment_id = iu.appointment_id;
-----------