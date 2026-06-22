drop function if exists get_appointments_of_doctor(dr_id int, on_date date);
create function get_appointments_of_doctor(dr_id int, on_date date default current_date)
    returns table
            (
                appointment_id   int,
                patient_name     varchar(128),
                location_id      varchar(16),
                appointment_time timestamp,
                status           appointment_status
            )
    language plpgsql
    stable
as
$$
begin
    return query select a.appointment_id, p.full_name, a.location_id, a.appointment_time, a.status
                 from appointment a
                          inner join patient p on a.patient_id = p.patient_id
                 where a.doctor_id = dr_id
                   and a.appointment_time >= on_date
                   and a.appointment_time < on_date + interval '1 day'
                 order by a.appointment_time;
end;
$$;

drop function if exists get_appointments_by_status(a_status appointment_status, on_date date);
create function get_appointments_by_status(a_status appointment_status, on_date date default current_date)
    returns table
            (
                appointment_id   int,
                patient_name     varchar(128),
                doctor_name      varchar(128),
                location_id      varchar(16),
                appointment_time timestamp
            )
    language plpgsql
    stable
as
$$
begin
    return query select a.appointment_id, p.full_name, dr.full_name, a.location_id, a.appointment_time
                 from appointment a
                          inner join patient p on a.patient_id = p.patient_id
                          inner join employee dr on a.doctor_id = dr.employee_id
                 where a.status = a_status
                   and a.appointment_time >= on_date
                   and a.appointment_time < on_date + interval '1 day'
                 order by a.appointment_time;
end;
$$