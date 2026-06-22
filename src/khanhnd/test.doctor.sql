drop index if exists idx_appt_time,idx_appt_status;
create index idx_appt_time on appointment (appointment_time);
create index idx_appt_status on appointment (status);
explain analyse
select *
from get_appointments_by_status('waiting'::appointment_status, '2026-05-20');

drop index if exists idx_appt_pat,idx_appt_dr,idx_appt_serv_appt,idx_appt_serv_serv,idx_appt_sup_appt,idx_appt_sup_sup,idx_appt_time;
create index idx_appt_pat on appointment (patient_id);
create index idx_appt_dr on appointment (doctor_id);
create index idx_appt_serv_appt on appointment_service (appointment_id);
create index idx_appt_serv_serv on appointment_service (service_id);
create index idx_appt_sup_appt on appointment_supply (appointment_id);
create index idx_appt_sup_sup on appointment_supply (supply_id);
create index idx_appt_time on appointment (appointment_time);
explain analyse
select da.appointment_id, patient_name, ai.supply_fee, ai.service_fee, ai.final_amount
from get_appointments_of_doctor(12, '2024-06-14') da
         inner join appointment_invoice ai on da.appointment_id = ai.appointment_id;