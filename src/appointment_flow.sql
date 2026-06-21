-- -------------------------------------------------------
-- 1. start_appointment: chuyển trạng thái từ waiting -> ongoing
-- -------------------------------------------------------
create or replace function start_appointment(p_appointment_id int)
returns text
language plpgsql as $$
declare
    v_status appointment_status;
begin
    select status into v_status
    from appointment where appointment_id = p_appointment_id;

    if not found then
        return 'error: lịch hẹn không tồn tại';
    end if;

    if v_status != 'waiting' then
        return 'error: chỉ có thể bắt đầu ca khám ở trạng thái waiting. trạng thái hiện tại: ' || v_status;
    end if;

    update appointment set status = 'ongoing' where appointment_id = p_appointment_id;

    return 'ok: bắt đầu ca khám thành công. mã lịch hẹn: ' || p_appointment_id;
end;
$$;

-- test start_appointment
select * from appointment;
select start_appointment(1000); -- lịch hẹn không tồn tại
select start_appointment(1);  -- chỉ có thể bắt đầu ca khám có trạng thái là waiting
select start_appointment(5);   -- thành công

-- -------------------------------------------------------
-- 2. add_service_to_appointment: thêm dịch vụ vào lịch hẹn
-- -------------------------------------------------------
create or replace function add_service_to_appointment(
    p_appointment_id int,
    p_service_id int,
    p_quantity int default 1,
    p_service_result text default null
)
returns text
language plpgsql as $$
declare
    v_status appointment_status;
    v_service_exists int;
begin
    select status into v_status
    from appointment where appointment_id = p_appointment_id;

    if not found then
        return 'error: lịch hẹn không tồn tại';
    end if;

    if v_status != 'ongoing' then
        return 'error: chỉ có thể thêm dịch vụ khi ca khám đang diễn ra (ongoing)';
    end if;

    select count(*) into v_service_exists
    from service where service_id = p_service_id;

    if v_service_exists = 0 then
        return 'error: dịch vụ không tồn tại';
    end if;

    insert into appointment_service (appointment_id, service_id, quantity, service_result)
    values (p_appointment_id, p_service_id, p_quantity, p_service_result)
    on conflict (appointment_id, service_id)
    do update set quantity = appointment_service.quantity + excluded.quantity,
                  service_result = coalesce(excluded.service_result, appointment_service.service_result);

    return 'ok: đã thêm dịch vụ vào ca khám';
end;
$$;

-- test add_service_to_appointment
select * from appointment;
select * from service;
select add_service_to_appointment(5001, 1); -- lịch hẹn không tồn tại
select add_service_to_appointment(13, 1); -- chỉ có ca khám đang diễn ra mới được thêm dịch vụ
select add_service_to_appointment(3, 101); -- dịch vụ không tồn tại
select add_service_to_appointment(3, 1, 2, 'huyết áp bình thường'); -- thêm thành công
select * from appointment_service where appointment_id = 3; -- kiểm tra dịch vụ đã thêm thành công

