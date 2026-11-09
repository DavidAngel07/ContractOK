-- ContractOK · Semana 2 · Pruebas de contratistas, trabajadores e invitaciones
-- Cómo usarlo: pega TODO este archivo en el Editor SQL de Supabase (proyecto contractok-dev) y ejecútalo.
-- Todo ocurre dentro de una transacción que termina con ROLLBACK: no deja datos en tu base.
-- Si algo falla, verás un error que empieza con "FALLÓ". Si todo pasa, el último resultado dice OK.

begin;

-- ===== Preparación =====
do $$
begin
  insert into auth.users (id, email) values
    ('00000000-0000-0000-0000-000000000a01', 'admin.a@test.local'),
    ('00000000-0000-0000-0000-000000000a02', 'supervisor.a@test.local'),
    ('00000000-0000-0000-0000-000000000a03', 'consulta.a@test.local'),
    ('00000000-0000-0000-0000-000000000b01', 'admin.b@test.local'),
    ('00000000-0000-0000-0000-000000000c01', 'natural@contratista.com'),
    ('00000000-0000-0000-0000-000000000c02', 'empresa@contratista.com'),
    ('00000000-0000-0000-0000-000000000c03', 'claim3@contratista.com'),
    ('00000000-0000-0000-0000-000000000d01', 'otro@correo.com');

  insert into public.companies (id, name) values
    ('00000000-0000-0000-0000-00000000aaaa', 'Empresa A'),
    ('00000000-0000-0000-0000-00000000bbbb', 'Empresa B');

  perform public.add_member('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-000000000a01', 'Administrador');
  perform public.add_member('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-000000000a02', 'Supervisor de contrato');
  perform public.add_member('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-000000000a03', 'Consulta');
  perform public.add_member('00000000-0000-0000-0000-00000000bbbb', '00000000-0000-0000-0000-000000000b01', 'Administrador');

  insert into public.contractors (id, company_id, kind, display_name, email) values
    ('00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000aaaa', 'natural', 'Carlos Natural', 'natural@contratista.com'),
    ('00000000-0000-0000-0000-00000000a002', '00000000-0000-0000-0000-00000000aaaa', 'company', 'Empresa Contratista A2', 'empresa@contratista.com'),
    ('00000000-0000-0000-0000-00000000a003', '00000000-0000-0000-0000-00000000aaaa', 'natural', 'Laura Claim', 'claim3@contratista.com'),
    ('00000000-0000-0000-0000-00000000b001', '00000000-0000-0000-0000-00000000bbbb', 'company', 'Contratista de B', 'empresa-b@contratista.com');

  insert into public.contractor_members (user_id, contractor_id) values
    ('00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000a001'),
    ('00000000-0000-0000-0000-000000000c02', '00000000-0000-0000-0000-00000000a002');
end $$;

-- ===== Grupo 1: administrador de la empresa A =====
do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000aaaa';
  b constant uuid := '00000000-0000-0000-0000-00000000bbbb';
  n integer; failed boolean; v_inv jsonb;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000a01","role":"authenticated"}', true);
  set local role authenticated;

  select count(*) into n from public.contractors where company_id = a;
  if n <> 3 then raise exception 'FALLÓ [1.1]: el administrador A debe ver 3 contratistas y ve %', n; end if;
  select count(*) into n from public.contractors where company_id = b;
  if n <> 0 then raise exception 'FALLÓ [1.2]: el administrador A ve contratistas de la empresa B'; end if;

  insert into public.contractors (company_id, kind, display_name, email) values (a, 'natural', 'Nuevo', 'nuevo@contratista.com');
  select count(*) into n from public.contractors where company_id = a and created_by = '00000000-0000-0000-0000-000000000a01';
  if n <> 1 then raise exception 'FALLÓ [1.3]: created_by no se llenó con el usuario autenticado'; end if;

  failed := false;
  begin
    insert into public.contractors (company_id, kind, display_name, email) values (b, 'natural', 'Intruso', 'intruso@x.com');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [1.4]: el administrador A pudo crear un contratista en la empresa B'; end if;

  update public.contractors set phone = '3001234567' where id = '00000000-0000-0000-0000-00000000a001';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLÓ [1.5]: no pudo editar un contratista de su empresa'; end if;

  update public.contractors set phone = 'hack' where id = '00000000-0000-0000-0000-00000000b001';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLÓ [1.6]: pudo editar un contratista de otra empresa'; end if;

  failed := false;
  begin
    delete from public.contractors where id = '00000000-0000-0000-0000-00000000a001';
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [1.7]: se pudo borrar un contratista (solo se archivan)'; end if;

  -- Trabajadores: solo empresas contratistas
  insert into public.workers (company_id, contractor_id, full_name, id_number)
  values (a, '00000000-0000-0000-0000-00000000a002', 'Pedro Operario', '1001');
  failed := false;
  begin
    insert into public.workers (company_id, contractor_id, full_name, id_number)
    values (a, '00000000-0000-0000-0000-00000000a001', 'No Debería', '1002');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [1.8]: un contratista persona natural recibió un trabajador'; end if;

  -- Invitaciones
  v_inv := public.create_invitation('00000000-0000-0000-0000-00000000a003');
  if length(v_inv ->> 'token') <> 64 then raise exception 'FALLÓ [1.9]: el token debe tener 64 caracteres'; end if;
  perform set_config('test.token_a3', v_inv ->> 'token', true);

  failed := false;
  begin
    perform public.create_invitation('00000000-0000-0000-0000-00000000b001');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [1.10]: invitó a un contratista de otra empresa'; end if;

  select count(id) into n from public.invitations where contractor_id = '00000000-0000-0000-0000-00000000a003';
  if n <> 1 then raise exception 'FALLÓ [1.11]: el administrador debe ver la invitación creada'; end if;

  failed := false;
  begin
    perform token_hash from public.invitations;
  exception when insufficient_privilege then failed := true; end;
  if not failed then raise exception 'FALLÓ [1.12]: se pudo leer token_hash desde el cliente'; end if;

  -- Una sola invitación vigente: al crear otra, la anterior se anula
  v_inv := public.create_invitation('00000000-0000-0000-0000-00000000a003');
  select count(id) into n from public.invitations
  where contractor_id = '00000000-0000-0000-0000-00000000a003' and revoked_at is null and used_at is null;
  if n <> 1 then raise exception 'FALLÓ [1.13]: debe quedar 1 sola invitación vigente y hay %', n; end if;
  perform set_config('test.token_a3', v_inv ->> 'token', true);

  reset role;
end $$;

-- ===== Grupo 2: supervisor (alcance "asignados") =====
do $$
declare n integer; failed boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a02', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000a02","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into n from public.contractors;
  if n <> 0 then raise exception 'FALLÓ [2.1]: un supervisor sin asignaciones ve % contratistas', n; end if;
  reset role;
end $$;

insert into public.contractor_assignments (contractor_id, user_id)
values ('00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-000000000a02');

do $$
declare n integer; failed boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a02', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000a02","role":"authenticated"}', true);
  set local role authenticated;

  select count(*) into n from public.contractors;
  if n <> 1 then raise exception 'FALLÓ [2.2]: el supervisor debe ver solo su contratista asignado y ve %', n; end if;

  failed := false;
  begin
    insert into public.contractors (company_id, kind, display_name, email)
    values ('00000000-0000-0000-0000-00000000aaaa', 'natural', 'X', 'x@x.com');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [2.3]: un supervisor pudo crear contratistas'; end if;

  update public.contractors set phone = 'x' where id = '00000000-0000-0000-0000-00000000a001';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLÓ [2.4]: un supervisor pudo editar un contratista'; end if;

  reset role;
end $$;

-- Una persona de otra empresa no puede ser asignada
do $$
declare failed boolean := false;
begin
  begin
    insert into public.contractor_assignments (contractor_id, user_id)
    values ('00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-000000000b01');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [2.5]: se asignó a una persona de otra empresa'; end if;
end $$;

-- ===== Grupo 3: rol Consulta (solo lectura) =====
do $$
declare n integer; failed boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a03', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000a03","role":"authenticated"}', true);
  set local role authenticated;

  select count(*) into n from public.contractors where company_id = '00000000-0000-0000-0000-00000000aaaa';
  if n < 3 then raise exception 'FALLÓ [3.1]: Consulta debe ver los contratistas de su empresa'; end if;
  select count(*) into n from public.contractors where company_id = '00000000-0000-0000-0000-00000000bbbb';
  if n <> 0 then raise exception 'FALLÓ [3.2]: Consulta ve contratistas de otra empresa'; end if;

  failed := false;
  begin
    insert into public.contractors (company_id, kind, display_name, email)
    values ('00000000-0000-0000-0000-00000000aaaa', 'natural', 'X', 'y@x.com');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [3.3]: Consulta pudo crear un contratista'; end if;

  failed := false;
  begin
    perform public.create_invitation('00000000-0000-0000-0000-00000000a001');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [3.4]: Consulta pudo crear una invitación'; end if;

  select count(id) into n from public.invitations;
  if n <> 0 then raise exception 'FALLÓ [3.5]: Consulta ve invitaciones'; end if;

  reset role;
end $$;

-- ===== Grupo 4: contratista persona natural =====
do $$
declare n integer; failed boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000c01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000c01","role":"authenticated"}', true);
  set local role authenticated;

  select count(*) into n from public.contractors;
  if n <> 1 then raise exception 'FALLÓ [4.1]: el contratista debe ver solo su registro y ve %', n; end if;

  update public.contractors set status = 'enabled' where id = '00000000-0000-0000-0000-00000000a001';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLÓ [4.2]: el contratista pudo cambiar su propio estado'; end if;

  select count(*) into n from public.companies;
  if n <> 0 then raise exception 'FALLÓ [4.3]: el contratista ve empresas directamente'; end if;
  select count(id) into n from public.invitations;
  if n <> 0 then raise exception 'FALLÓ [4.4]: el contratista ve invitaciones'; end if;

  failed := false;
  begin
    insert into public.workers (company_id, contractor_id, full_name, id_number)
    values ('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-00000000a001', 'X', '9');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [4.5]: contratista natural creó un trabajador'; end if;

  failed := false;
  begin
    perform public.create_invitation('00000000-0000-0000-0000-00000000a001');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [4.6]: un contratista pudo crear invitaciones'; end if;

  select count(*) into n from public.my_contractor_portal() where company_name = 'Empresa A';
  if n <> 1 then raise exception 'FALLÓ [4.7]: my_contractor_portal debe devolver su contratista y empresa'; end if;

  reset role;
end $$;

-- ===== Grupo 5: contratista empresa con trabajadores =====
do $$
declare n integer; failed boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000c02', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000c02","role":"authenticated"}', true);
  set local role authenticated;

  insert into public.workers (company_id, contractor_id, full_name, id_number)
  values ('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-00000000a002', 'Ana Operaria', '2001');

  select count(*) into n from public.workers;
  if n <> 2 then raise exception 'FALLÓ [5.1]: debe ver 2 trabajadores propios y ve %', n; end if;
  select count(*) into n from public.workers where contractor_id <> '00000000-0000-0000-0000-00000000a002';
  if n <> 0 then raise exception 'FALLÓ [5.2]: ve trabajadores de otros contratistas'; end if;

  failed := false;
  begin
    insert into public.workers (company_id, contractor_id, full_name, id_number)
    values ('00000000-0000-0000-0000-00000000bbbb', '00000000-0000-0000-0000-00000000b001', 'Intruso', '3001');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [5.3]: agregó un trabajador a otro contratista'; end if;

  failed := false;
  begin
    insert into public.workers (company_id, contractor_id, full_name, id_number)
    values ('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-00000000a002', 'Repetido', '2001');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [5.4]: se repitió el número de documento de un trabajador'; end if;

  reset role;
end $$;

-- ===== Grupo 6: flujo completo de invitación =====
do $$
declare
  v_tok text := current_setting('test.token_a3');
  v_state text; v_hint text; v_contractor uuid; v_status text; n integer; failed boolean;
begin
  -- Vista previa pública
  set local role anon;
  select state, email_hint into v_state, v_hint from public.get_invitation_preview(v_tok);
  if v_state <> 'valid' then raise exception 'FALLÓ [6.1]: la vista previa debe ser valid y es %', v_state; end if;
  if v_hint <> 'c***@contratista.com' then raise exception 'FALLÓ [6.2]: pista de correo incorrecta: %', v_hint; end if;
  select state into v_state from public.get_invitation_preview('token-inventado');
  if v_state <> 'invalid' then raise exception 'FALLÓ [6.3]: un token inventado debe ser invalid'; end if;
  reset role;

  -- Otra persona con sesión NO puede reclamarla (correo distinto)
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000d01","role":"authenticated"}', true);
  set local role authenticated;
  failed := false;
  begin perform public.claim_invitation(v_tok);
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [6.4]: otra persona pudo reclamar la invitación'; end if;
  failed := false;
  begin perform public.claim_invitation('token-inventado');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [6.5]: se reclamó con un token inventado'; end if;
  reset role;

  -- La persona correcta (correo coincide) sí puede
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000c03', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000c03","role":"authenticated"}', true);
  set local role authenticated;
  v_contractor := public.claim_invitation(v_tok);
  if v_contractor <> '00000000-0000-0000-0000-00000000a003' then raise exception 'FALLÓ [6.6]: devolvió otro contratista'; end if;
  select status into v_status from public.contractors where id = v_contractor;
  if v_status <> 'filling' then raise exception 'FALLÓ [6.7]: el estado debe pasar a filling y es %', v_status; end if;
  select count(*) into n from public.my_contractor_portal();
  if n <> 1 then raise exception 'FALLÓ [6.8]: el portal debe mostrar su contratista'; end if;
  perform public.claim_invitation(v_tok); -- reclamar de nuevo es inofensivo
  reset role;

  -- Una vez usada, nadie más puede reclamarla y la vista previa lo indica
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000d01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000d01","role":"authenticated"}', true);
  set local role authenticated;
  failed := false;
  begin perform public.claim_invitation(v_tok);
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [6.9]: se reclamó una invitación ya usada'; end if;
  reset role;
  set local role anon;
  select state into v_state from public.get_invitation_preview(v_tok);
  if v_state <> 'used' then raise exception 'FALLÓ [6.10]: la vista previa debe ser used y es %', v_state; end if;
  reset role;
end $$;

-- ===== Grupo 7: anular y vencer invitaciones =====
do $$
declare v_tok text; v_id uuid; v_state text; failed boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000a01","role":"authenticated"}', true);
  set local role authenticated;
  v_tok := public.create_invitation('00000000-0000-0000-0000-00000000a002') ->> 'token';
  select id into v_id from public.invitations
  where contractor_id = '00000000-0000-0000-0000-00000000a002' and revoked_at is null and used_at is null;
  perform public.revoke_invitation(v_id);
  reset role;

  set local role anon;
  select state into v_state from public.get_invitation_preview(v_tok);
  if v_state <> 'revoked' then raise exception 'FALLÓ [7.1]: debe estar revoked y es %', v_state; end if;
  reset role;

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000c02', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000c02","role":"authenticated"}', true);
  set local role authenticated;
  failed := false;
  begin perform public.claim_invitation(v_tok);
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [7.2]: se reclamó una invitación anulada'; end if;
  reset role;
end $$;

-- Invitación vencida (se fuerza la fecha como superadmin)
do $$
declare v_tok text; v_state text; failed boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000a01","role":"authenticated"}', true);
  set local role authenticated;
  v_tok := public.create_invitation('00000000-0000-0000-0000-00000000a002') ->> 'token';
  reset role;

  update public.invitations set expires_at = now() - interval '1 day'
  where contractor_id = '00000000-0000-0000-0000-00000000a002' and revoked_at is null and used_at is null;

  set local role anon;
  select state into v_state from public.get_invitation_preview(v_tok);
  if v_state <> 'expired' then raise exception 'FALLÓ [7.3]: debe estar expired y es %', v_state; end if;
  reset role;

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000c02', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000c02","role":"authenticated"}', true);
  set local role authenticated;
  failed := false;
  begin perform public.claim_invitation(v_tok);
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [7.4]: se reclamó una invitación vencida'; end if;
  reset role;
end $$;

-- ===== Grupo 8: otra empresa y visitante anónimo =====
do $$
declare n integer; failed boolean; denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000b01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000b01","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into n from public.contractors where company_id = '00000000-0000-0000-0000-00000000aaaa';
  if n <> 0 then raise exception 'FALLÓ [8.1]: el administrador B ve contratistas de A'; end if;
  select count(*) into n from public.workers;
  if n <> 0 then raise exception 'FALLÓ [8.2]: el administrador B ve trabajadores de A'; end if;
  failed := false;
  begin perform public.create_invitation('00000000-0000-0000-0000-00000000a003');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [8.3]: el administrador B invitó a un contratista de A'; end if;
  reset role;

  set local role anon;
  begin
    select count(*) into n from public.contractors;
    if n <> 0 then raise exception 'FALLÓ [8.4]: un visitante anónimo ve contratistas'; end if;
  exception when insufficient_privilege then denied := true; end;
  reset role;
end $$;

-- ===== Grupo 9: reglas de datos (como superadmin) =====
do $$
declare failed boolean := false;
begin
  begin
    insert into public.contractors (company_id, kind, display_name, email)
    values ('00000000-0000-0000-0000-00000000aaaa', 'natural', 'Duplicado', 'NATURAL@contratista.com');
  exception when unique_violation then failed := true; end;
  if not failed then raise exception 'FALLÓ [9.1]: se repitió el correo de un contratista en la misma empresa'; end if;

  -- Eliminar la empresa elimina en cascada todo lo relacionado
  delete from public.companies where id = '00000000-0000-0000-0000-00000000aaaa';
  if exists (select 1 from public.contractors where company_id = '00000000-0000-0000-0000-00000000aaaa')
     or exists (select 1 from public.invitations where company_id = '00000000-0000-0000-0000-00000000aaaa') then
    raise exception 'FALLÓ [9.2]: al eliminar la empresa quedaron datos huérfanos';
  end if;
end $$;

rollback;

select 'OK: todas las pruebas de la semana 2 pasaron' as resultado;
