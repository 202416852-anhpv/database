drop function if exists update_patient_timestamp;
create function update_patient_timestamp()
    returns trigger
    language plpgsql
as
$$
begin
    if row (old.full_name, old.date_of_birth, old.gender, old.phone_number, old.address) is distinct from row (new.full_name, new.date_of_birth, new.gender, new.phone_number, new.address) then
        new.updated_at = current_timestamp;
    end if;
    return new;
end;
$$;

drop trigger if exists trg_patient_updated_at on patient;
create trigger trg_patient_updated_at
    before update
    on patient
    for each row
execute function update_patient_timestamp();

drop function if exists create_patient;
create function create_patient(
    p_full_name varchar(128),
    p_date_of_birth date,
    p_gender gender_value,
    p_phone_number char(10),
    p_address text default null
)
    returns int
    language plpgsql
as
$$
declare
    new_id int;
begin
    insert into patient (full_name, date_of_birth, gender, phone_number, address)
    values (p_full_name, p_date_of_birth, p_gender, p_phone_number, p_address)
    returning patient_id into new_id;
    return new_id;
end;
$$;

drop function if exists get_patient;
create function get_patient(p_patient_id int)
    returns table
            (
                patient_id    int,
                full_name     varchar(128),
                date_of_birth date,
                gender        gender_value,
                phone_number  char(10),
                address       text,
                created_at    timestamp,
                updated_at    timestamp
            )
    language plpgsql
    stable
as
$$
begin
    return query
        select p.patient_id,
               p.full_name,
               p.date_of_birth,
               p.gender,
               p.phone_number,
               p.address,
               p.created_at,
               p.updated_at
        from patient p
        where p.patient_id = p_patient_id;
end;
$$;

drop function if exists update_patient;
create function update_patient(
    p_patient_id int,
    p_full_name varchar(128) default null,
    p_date_of_birth date default null,
    p_gender gender_value default null,
    p_phone_number char(10) default null,
    p_address text default null
)
    returns boolean
    language plpgsql
as
$$
begin
    update patient
    set full_name     = coalesce(p_full_name, full_name),
        date_of_birth = coalesce(p_date_of_birth, date_of_birth),
        gender        = coalesce(p_gender, gender),
        phone_number  = coalesce(p_phone_number, phone_number),
        address       = coalesce(p_address, address)
    where patient_id = p_patient_id;
    return found;
end;
$$;

drop function if exists delete_patient;
create function delete_patient(p_patient_id int)
    returns boolean
    language plpgsql
as
$$
begin
    delete from patient where patient_id = p_patient_id;
    return found;
end;
$$;

drop function if exists get_patient_appointments;
create function get_patient_appointments(p_patient_id int, on_date date default null)
    returns table
            (
                appointment_id   int,
                doctor_name      varchar(128),
                location_id      varchar(16),
                appointment_time timestamp,
                status           appointment_status,
                payment_status   boolean,
                symptoms         text,
                diagnosis        text,
                doctor_notes     text
            )
    language plpgsql
    stable
as
$$
begin
    return query
        select a.appointment_id,
               dr.full_name,
               a.location_id,
               a.appointment_time,
               a.status,
               a.payment_status,
               a.symptoms,
               a.diagnosis,
               a.doctor_notes
        from appointment a
                 inner join employee dr on a.doctor_id = dr.employee_id
        where a.patient_id = p_patient_id
          and (on_date is null or (a.appointment_time >= on_date and a.appointment_time < on_date + interval '1 day'))
        order by a.appointment_time;
end;
$$;

drop function if exists schedule_appointment;
create function schedule_appointment(
    p_patient_id int,
    p_doctor_id int,
    p_location_id varchar(16),
    p_appointment_time timestamp
)
    returns int
    language plpgsql
as
$$
declare
    new_id int;
begin
    if not exists (select 1 from employee where employee_id = p_doctor_id and title = 'doctor') then
        raise exception 'employee % is not a doctor', p_doctor_id;
    end if;
    insert into appointment (patient_id, doctor_id, location_id, appointment_time)
    values (p_patient_id, p_doctor_id, p_location_id, p_appointment_time)
    returning appointment_id into new_id;
    return new_id;
end;
$$;

drop function if exists cancel_appointment;
create function cancel_appointment(p_appointment_id int, p_patient_id int)
    returns boolean
    language plpgsql
as
$$
begin
    update appointment
    set status = 'cancelled'
    where appointment_id = p_appointment_id
      and patient_id = p_patient_id
      and status = 'waiting'
      and appointment_time > current_timestamp;
    if not found then
        raise exception 'appointment % not found, already processed, or in the past', p_appointment_id;
    end if;
    return true;
end;
$$;
