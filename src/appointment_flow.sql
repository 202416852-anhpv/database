-- -------------------------------------------------------
-- 1. create_appointment: khởi tạo ca khám bệnh
-- -------------------------------------------------------
create or replace function create_appointment(
    p_patient_id int,
    p_doctor_id int,
    p_location_id varchar(16),
    p_appointment_time timestamp,
    p_symptoms text default null
)
returns text
language plpgsql as $$
declare
    v_new_id int;
begin
    -- 1. kiểm tra dữ liệu bắt buộc (ví dụ thời gian khám không được để trống)
    if p_appointment_time is null then
        return 'error: thời gian hẹn khám không được để trống';
    end if;

    -- 2. chèn dữ liệu mới vào bảng appointment
    insert into appointment (
        patient_id, 
        doctor_id, 
        location_id, 
        appointment_time, 
        symptoms
    )
    values (
        p_patient_id, 
        p_doctor_id, 
        p_location_id, 
        p_appointment_time, 
        p_symptoms
    )
    returning appointment_id into v_new_id;

    -- 3. trả về thông báo kèm id vừa tạo để frontend/backend tiện sử dụng
    return 'ok: tạo lịch hẹn khám thành công. mã lịch hẹn: ' || v_new_id;
end;
$$;

-- test start_appointment
select create_appointment(10, 20, 'A-001', '2026-06-26 10:30:00');

-- -------------------------------------------------------
-- 2. start_appointment: chuyển trạng thái từ waiting -> ongoing
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
-- 3. add_service_to_appointment: thêm dịch vụ vào lịch hẹn
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

-- -------------------------------------------------------
-- 4. add_supply_to_appointment: thêm thuốc/vật tư
--    kiểm tra tồn kho trước khi thêm
-- -------------------------------------------------------
create or replace function add_supply_to_appointment(
    p_appointment_id int,
    p_supply_id int,
    p_quantity int default 1,
    p_instruction text default null
)
returns text
language plpgsql as $$
declare
    v_status      appointment_status;
    v_supply_name varchar(128);
    v_in_stock    int;
begin
    select status into v_status
    from appointment where appointment_id = p_appointment_id;

    if not found then
        return 'error: lịch hẹn không tồn tại';
    end if;

    if v_status != 'ongoing' then
        return 'error: chỉ có thể thêm thuốc khi ca khám đang diễn ra (ongoing)';
    end if;

    select supply_name, quantity_in_stock into v_supply_name, v_in_stock
    from medical_supply where supply_id = p_supply_id;

    if not found then
        return 'error: thuốc/vật tư không tồn tại';
    end if;

    if v_in_stock < p_quantity then
        return 'error: không đủ tồn kho. yêu cầu: ' || p_quantity
               || ', tồn kho: ' || v_in_stock || ' (' || v_supply_name || ')';
    end if;

    insert into appointment_supply (appointment_id, supply_id, quantity, instruction)
    values (p_appointment_id, p_supply_id, p_quantity, p_instruction)
    on conflict (appointment_id, supply_id)
    do update set quantity = appointment_supply.quantity + excluded.quantity,
                  instruction = coalesce(excluded.instruction, appointment_supply.instruction);

    return 'ok: đã thêm thuốc/vật tư vào ca khám';
end;
$$;

-- test add_supply_to_appointmen
select * from medical_supply;
select * from appointment;
select add_supply_to_appointment(5001, 101, 5); -- lịch hẹn không tồn tại
select add_supply_to_appointment(1, 101, 5); -- chỉ có ca khám đang diễn ra mới được thêm dịch vụ
select add_supply_to_appointment(4, 201, 5); -- thuốc/vật tư không tồn tại
select add_supply_to_appointment(4, 100, 1000); -- không đủ số lượng trong kho
select add_supply_to_appointment(4, 100, 1, 'ngày uống 2 viên');
select quantity_in_stock from medical_supply where supply_id = 100; -- kiểm tra kết quả
select * from appointment_supply where appointment_id = 4 and supply_id = 100; -- kiểm tra kết quả

-- -------------------------------------------------------
-- 5. finish_appointment: ongoing → finished
--    ghi chẩn đoán + giảm tồn kho thuốc đã kê
-- -------------------------------------------------------
create or replace function finish_appointment(
    p_appointment_id int,
    p_diagnosis varchar(256),
    p_doctor_notes varchar(256) default null
)
returns text
language plpgsql as $$
declare
    v_status appointment_status;
begin
    -- 1. kiểm tra lịch hẹn có tồn tại không
    select status into v_status
    from appointment where appointment_id = p_appointment_id;

    if not found then
        return 'error: lịch hẹn không tồn tại';
    end if;

    -- 2. kiểm tra trạng thái ca khám phải đang diễn ra (ongoing)
    if v_status != 'ongoing' then
        return 'error: chỉ có thể kết thúc ca khám đang diễn ra (ongoing)';
    end if;

    -- 3. CHỐT SỔ: thực hiện trừ kho hàng loạt cho tất cả thuốc/vật tư đã kê trong ca này
    update medical_supply ms
    set quantity_in_stock = ms.quantity_in_stock - asu.quantity
    from appointment_supply asu
    where asu.supply_id = ms.supply_id
      and asu.appointment_id = p_appointment_id;

    -- 4. cập nhật thông tin chẩn đoán và đóng ca khám
    update appointment
    set status = 'finished',
        diagnosis = p_diagnosis,
        doctor_notes = p_doctor_notes
    where appointment_id = p_appointment_id;

    return 'ok: kết thúc ca khám thành công và đã khấu trừ kho. mã lịch hẹn: ' || p_appointment_id;
end;
$$;

-- test finish_appointment
select * from appointment;
select finish_appointment(5001, 'viêm họng cấp'); -- Lịch khám không tồn tại
select finish_appointment(1, 'đau đầu chưa rõ nguyên nhân'); -- chỉ có ca khám đang diễn ra mới kết thúc được
select finish_appointment(10, 'viêm phế quản cấp', 'cho nghỉ ngơi 3 ngày, tái khám nếu sốt lại');
select quantity_in_stock from medical_supply where supply_id = 100; -- kiểm tra kết quả
select * from appointment where appointment_id = 10; -- kiểm tra kết quả
