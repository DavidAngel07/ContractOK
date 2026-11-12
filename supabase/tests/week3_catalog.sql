-- ContractOK · Semana 3 · Pruebas del catálogo, perfiles de requisitos e invitación de personal
-- Pega TODO este archivo en el Editor SQL de Supabase (contractok-dev) y ejecútalo. Termina con ROLLBACK (no deja datos).
-- Si algo falla verás un error que empieza con "FALLÓ". Si todo pasa, el último resultado dice OK.

begin;

do $$
declare n integer;
begin
  insert into auth.users (id, email) values
    ('00000000-0000-0000-0000-000000000a01', 'admin.a@test.local'),
    ('00000000-0000-0000-0000-000000000a02', 'supervisor.a@test.local'),
    ('00000000-0000-0000-0000-000000000a03', 'consulta.a@test.local'),
    ('00000000-0000-0000-0000-000000000b01', 'admin.b@test.local'),
    ('00000000-0000-0000-0000-000000000e01', 'nuevo.personal@correo.com'),
    ('00000000-0000-0000-0000-000000000e02', 'otra.persona@correo.com');
  insert into public.companies (id, name) values
    ('00000000-0000-0000-0000-00000000aaaa', 'Empresa A'),
    ('00000000-0000-0000-0000-00000000bbbb', 'Empresa B');
  perform public.add_member('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-000000000a01', 'Administrador');
  perform public.add_member('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-000000000a02', 'Supervisor de contrato');
  perform public.add_member('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-000000000a03', 'Consulta');
  perform public.add_member('00000000-0000-0000-0000-00000000bbbb', '00000000-0000-0000-0000-000000000b01', 'Administrador');

  -- Catálogo inicial
  select count(*) into n from public.document_types where company_id = '00000000-0000-0000-0000-00000000aaaa';
  if n <> 19 then raise exception 'FALLÓ [0.1]: el catálogo inicial debe tener 19 documentos y tiene %', n; end if;
  select count(*) into n from public.requirement_profiles where company_id = '00000000-0000-0000-0000-00000000aaaa';
  if n <> 3 then raise exception 'FALLÓ [0.2]: deben crearse 3 perfiles y hay %', n; end if;
  select count(*) into n from public.requirement_profile_items where company_id = '00000000-0000-0000-0000-00000000aaaa';
  if n <> 10 + 16 + 17 then raise exception 'FALLÓ [0.3]: los perfiles deben tener 43 requisitos en total y tienen %', n; end if;
  select count(*) into n from public.document_types
  where company_id = '00000000-0000-0000-0000-00000000aaaa' and periodicity = 'expiring' and not requires_dates;
  if n <> 0 then raise exception 'FALLÓ [0.4]: hay documentos con vencimiento que no piden fechas'; end if;
  select count(*) into n from public.document_types
  where company_id = '00000000-0000-0000-0000-00000000aaaa' and owner_kind = 'worker';
  if n <> 5 then raise exception 'FALLÓ [0.5]: deben existir 5 documentos de trabajador y hay %', n; end if;
  select count(*) into n from public.document_types where company_id = '00000000-0000-0000-0000-00000000bbbb';
  if n <> 19 then raise exception 'FALLÓ [0.6]: la empresa B también debe recibir su catálogo'; end if;
end $$;

-- ===== Grupo 1: administrador de la empresa A =====
do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000aaaa';
  b constant uuid := '00000000-0000-0000-0000-00000000bbbb';
  n integer; failed boolean; v_type uuid; v_profile uuid; v_item_other uuid;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000a01","role":"authenticated"}', true);
  set local role authenticated;

  select count(*) into n from public.document_types;
  if n <> 19 then raise exception 'FALLÓ [1.1]: el administrador A debe ver 19 documentos y ve %', n; end if;
  select count(*) into n from public.requirement_profiles where company_id = b;
  if n <> 0 then raise exception 'FALLÓ [1.2]: ve perfiles de otra empresa'; end if;

  insert into public.document_types (company_id, name, phase, periodicity, requires_dates)
  values (a, 'Licencia de conducción', 'sst', 'expiring', true) returning id into v_type;

  failed := false;
  begin
    insert into public.document_types (company_id, name, phase, periodicity, requires_dates) values (a, 'Sin fechas', 'sst', 'expiring', false);
  exception when check_violation then failed := true; end;
  if not failed then raise exception 'FALLÓ [1.3]: se creó un documento con vencimiento sin pedir fechas'; end if;

  failed := false;
  begin
    insert into public.document_types (company_id, name, phase, periodicity) values (a, 'Licencia de conducción', 'sst', 'once');
  exception when unique_violation then failed := true; end;
  if not failed then raise exception 'FALLÓ [1.4]: se repitió el nombre de un documento'; end if;

  failed := false;
  begin
    insert into public.document_types (company_id, name, phase, periodicity) values (b, 'Intruso', 'sst', 'once');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [1.5]: creó un documento en otra empresa'; end if;

  update public.document_types set retention_years = 20 where id = v_type;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLÓ [1.6]: no pudo editar su documento'; end if;

  -- Perfiles
  insert into public.requirement_profiles (company_id, name, contractor_kind) values (a, 'Perfil de prueba', 'company') returning id into v_profile;
  insert into public.requirement_profile_items (requirement_profile_id, document_type_id, company_id) values (v_profile, v_type, a);

  select id into v_item_other from public.document_types where company_id = b limit 1;
  if v_item_other is not null then raise exception 'FALLÓ [1.7]: el administrador A ve el catálogo de B'; end if;

  failed := false;
  begin
    delete from public.document_types where id = v_type; -- está en un perfil
  exception when foreign_key_violation then failed := true; end;
  if not failed then raise exception 'FALLÓ [1.8]: se borró un documento que está en un perfil'; end if;

  delete from public.requirement_profile_items where requirement_profile_id = v_profile and document_type_id = v_type;
  delete from public.document_types where id = v_type;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLÓ [1.9]: no pudo borrar un documento sin uso'; end if;

  reset role;
end $$;

-- Un perfil no puede incluir documentos de otra empresa
do $$
declare failed boolean := false; v_foreign uuid; v_profile uuid;
begin
  select id into v_foreign from public.document_types where company_id = '00000000-0000-0000-0000-00000000bbbb' limit 1;
  select id into v_profile from public.requirement_profiles where company_id = '00000000-0000-0000-0000-00000000aaaa' limit 1;
  begin
    insert into public.requirement_profile_items (requirement_profile_id, document_type_id, company_id)
    values (v_profile, v_foreign, '00000000-0000-0000-0000-00000000aaaa');
  exception when foreign_key_violation then failed := true; end;
  if not failed then raise exception 'FALLÓ [2.1]: un perfil aceptó un documento de otra empresa'; end if;
end $$;

-- ===== Grupo 3: supervisor y consulta no configuran =====
do $$
declare n integer; failed boolean; u text;
begin
  foreach u in array array['00000000-0000-0000-0000-000000000a02', '00000000-0000-0000-0000-000000000a03'] loop
    perform set_config('request.jwt.claim.sub', u, true);
    perform set_config('request.jwt.claims', format('{"sub":"%s","role":"authenticated"}', u), true);
    set local role authenticated;
    select count(*) into n from public.document_types;
    if n <> 19 then raise exception 'FALLÓ [3.1]: % debe poder leer el catálogo', u; end if;
    failed := false;
    begin
      insert into public.document_types (company_id, name, phase, periodicity)
      values ('00000000-0000-0000-0000-00000000aaaa', 'No debería', 'sst', 'once');
    exception when others then failed := true; end;
    if not failed then raise exception 'FALLÓ [3.2]: % pudo crear un documento', u; end if;
    update public.document_types set name = 'Hack' where company_id = '00000000-0000-0000-0000-00000000aaaa';
    get diagnostics n = row_count;
    if n <> 0 then raise exception 'FALLÓ [3.3]: % pudo editar documentos', u; end if;
    delete from public.requirement_profiles where company_id = '00000000-0000-0000-0000-00000000aaaa';
    get diagnostics n = row_count;
    if n <> 0 then raise exception 'FALLÓ [3.4]: % pudo borrar perfiles', u; end if;
    reset role;
  end loop;
end $$;

-- ===== Grupo 4: perfil de requisitos asignado a un contratista =====
do $$
declare v_nat uuid; v_comp uuid; v_prof_comp uuid; v_prof_nat uuid; v_prof_b uuid; failed boolean; n integer;
begin
  select id into v_prof_nat from public.requirement_profiles where company_id = '00000000-0000-0000-0000-00000000aaaa' and contractor_kind = 'natural' limit 1;
  select id into v_prof_comp from public.requirement_profiles where company_id = '00000000-0000-0000-0000-00000000aaaa' and contractor_kind = 'company' limit 1;
  select id into v_prof_b from public.requirement_profiles where company_id = '00000000-0000-0000-0000-00000000bbbb' limit 1;

  insert into public.contractors (company_id, kind, display_name, email, requirement_profile_id)
  values ('00000000-0000-0000-0000-00000000aaaa', 'natural', 'Natural', 'nat@c.com', v_prof_nat) returning id into v_nat;
  insert into public.contractors (company_id, kind, display_name, email, requirement_profile_id)
  values ('00000000-0000-0000-0000-00000000aaaa', 'company', 'Empresa', 'emp@c.com', v_prof_comp) returning id into v_comp;

  failed := false;
  begin
    insert into public.contractors (company_id, kind, display_name, email, requirement_profile_id)
    values ('00000000-0000-0000-0000-00000000aaaa', 'natural', 'Mal perfil', 'mal@c.com', v_prof_comp);
  exception when check_violation then failed := true; end;
  if not failed then raise exception 'FALLÓ [4.1]: se asignó un perfil de empresa a una persona natural'; end if;

  failed := false;
  begin
    insert into public.contractors (company_id, kind, display_name, email, requirement_profile_id)
    values ('00000000-0000-0000-0000-00000000aaaa', 'natural', 'Perfil ajeno', 'ajeno@c.com', v_prof_b);
  exception when foreign_key_violation or check_violation then failed := true; end;
  if not failed then raise exception 'FALLÓ [4.2]: se asignó un perfil de otra empresa'; end if;

  failed := false;
  begin
    delete from public.requirement_profiles where id = v_prof_comp;
  exception when foreign_key_violation then failed := true; end;
  if not failed then raise exception 'FALLÓ [4.3]: se borró un perfil en uso'; end if;

  update public.requirement_profiles set is_active = false where id = v_prof_comp;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLÓ [4.4]: no se pudo desactivar un perfil en uso'; end if;
end $$;

-- ===== Grupo 5: invitación del personal =====
do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000aaaa';
  b constant uuid := '00000000-0000-0000-0000-00000000bbbb';
  v_role uuid; v_role_b uuid; v_inv uuid; n integer; failed boolean; v_name text;
begin
  select id into v_role from public.roles where company_id = a and name = 'Revisor SST';
  select id into v_role_b from public.roles where company_id = b and name = 'Consulta';

  -- El administrador invita
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000a01","role":"authenticated"}', true);
  set local role authenticated;
  v_inv := public.invite_staff(a, '  Nuevo.Personal@Correo.com ', v_role);
  select count(id) into n from public.staff_invitations where company_id = a and status = 'pending' and email = 'nuevo.personal@correo.com';
  if n <> 1 then raise exception 'FALLÓ [5.1]: la invitación debe quedar pendiente con el correo en minúsculas'; end if;

  failed := false;
  begin perform public.invite_staff(a, 'x@x.com', v_role_b);
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [5.2]: se invitó con un rol de otra empresa'; end if;

  failed := false;
  begin perform public.invite_staff(b, 'x@x.com', v_role_b);
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [5.3]: el administrador A invitó a la empresa B'; end if;

  failed := false;
  begin perform public.invite_staff(a, 'admin.a@test.local', v_role);
  exception when unique_violation then failed := true; end;
  if not failed then raise exception 'FALLÓ [5.4]: invitó a quien ya pertenece a la empresa'; end if;

  -- Reinvitar el mismo correo anula la anterior
  perform public.invite_staff(a, 'nuevo.personal@correo.com', v_role);
  select count(id) into n from public.staff_invitations where company_id = a and lower(email) = 'nuevo.personal@correo.com' and status = 'pending';
  if n <> 1 then raise exception 'FALLÓ [5.5]: debe quedar 1 sola invitación pendiente y hay %', n; end if;
  reset role;

  -- Consulta no puede invitar ni ver invitaciones
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a03', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000a03","role":"authenticated"}', true);
  set local role authenticated;
  failed := false;
  begin perform public.invite_staff(a, 'otro@x.com', v_role);
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [5.6]: Consulta pudo invitar'; end if;
  select count(id) into n from public.staff_invitations;
  if n <> 0 then raise exception 'FALLÓ [5.7]: Consulta ve invitaciones'; end if;
  reset role;

  -- La persona equivocada no activa nada; la correcta sí
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000e02', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000e02","role":"authenticated"}', true);
  set local role authenticated;
  if public.claim_staff_invitation() <> 0 then raise exception 'FALLÓ [5.8]: otra persona activó una invitación ajena'; end if;
  reset role;

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000e01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000e01","role":"authenticated"}', true);
  set local role authenticated;
  if public.claim_staff_invitation() <> 1 then raise exception 'FALLÓ [5.9]: la persona invitada no pudo activar su invitación'; end if;
  if public.claim_staff_invitation() <> 0 then raise exception 'FALLÓ [5.10]: la invitación se activó dos veces'; end if;
  select r.name into v_name from public.memberships m join public.roles r on r.id = m.role_id
  where m.user_id = '00000000-0000-0000-0000-000000000e01' and m.company_id = a and m.status = 'active';
  if v_name is distinct from 'Revisor SST' then raise exception 'FALLÓ [5.11]: la persona debe quedar con el rol Revisor SST y quedó con %', v_name; end if;
  select count(*) into n from public.companies;
  if n <> 1 then raise exception 'FALLÓ [5.12]: tras activarse debe ver su empresa'; end if;
  reset role;
end $$;

-- Anular e invitaciones vencidas
do $$
declare a constant uuid := '00000000-0000-0000-0000-00000000aaaa'; v_role uuid; v_inv uuid; failed boolean;
begin
  select id into v_role from public.roles where company_id = a and name = 'Consulta';
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000a01","role":"authenticated"}', true);
  set local role authenticated;
  v_inv := public.invite_staff(a, 'otra.persona@correo.com', v_role);
  perform public.revoke_staff_invitation(v_inv);
  reset role;

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000e02', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000e02","role":"authenticated"}', true);
  set local role authenticated;
  if public.claim_staff_invitation() <> 0 then raise exception 'FALLÓ [6.1]: se activó una invitación anulada'; end if;
  reset role;

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000a01","role":"authenticated"}', true);
  set local role authenticated;
  perform public.invite_staff(a, 'otra.persona@correo.com', v_role);
  reset role;
  update public.staff_invitations set expires_at = now() - interval '1 day' where lower(email) = 'otra.persona@correo.com' and status = 'pending';

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000e02', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000e02","role":"authenticated"}', true);
  set local role authenticated;
  if public.claim_staff_invitation() <> 0 then raise exception 'FALLÓ [6.2]: se activó una invitación vencida'; end if;
  reset role;

  -- Visitante anónimo
  set local role anon;
  failed := false;
  begin perform public.claim_staff_invitation();
  exception when insufficient_privilege then failed := true; end;
  reset role;
  if not failed then raise exception 'FALLÓ [6.3]: un visitante anónimo pudo llamar la función'; end if;
end $$;

rollback;

select 'OK: todas las pruebas de la semana 3 (catálogo e invitaciones) pasaron' as resultado;
