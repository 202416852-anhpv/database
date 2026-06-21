drop index if exists idx_appt_time,idx_appt_status;
create index idx_appt_time on appointment (appointment_time);
create index idx_appt_status on appointment (status);
explain analyse
select *
from get_appointments_by_status('waiting'::appointment_status, '2026-05-20')