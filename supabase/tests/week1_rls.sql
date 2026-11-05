-- ContractOK · Semana 1 · Pruebas de seguridad entre empresas y reglas de negocio
-- Cómo usarlo: pega TODO este archivo en el Editor SQL de Supabase (proyecto contractok-dev) y ejecútalo.
-- Todo ocurre dentro de una transacción que termina con ROLLBACK: no deja datos en tu base.
-- Si algo falla, verás un error que empieza con "FALLÓ". Si todo pasa, el último resultado dice OK.

begin;

-- ===== Preparación: 2 empresas, 4 usuarios =====
do $$
begin
  insert into auth.users (id, email) values
    ('00000000-0000-0000-0000-0000000000a1', 'admin.a@test.local'),
    ('00000000-0000-0000-0000-0000000000c1', 'consulta.a@test.local'),
    ('00000000-0000-0000-0000-0000000000b1', 'admin.b@test.local'),
    ('00000000-0000-0000-0000-0000000000d1', 'sin.empresa@test.local');

  insert into public.companies (id, name) values
    ('00000000-0000-0000-0000-00000000000a', 'Empresa A'),
    ('00000000-0000-0000-0000-00000000000b', 'Empresa B');

  perform public.add_member('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a1', 'Administrador');
  perform public.add_member('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000c1', 'Consulta');
  perform public.add_member('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000b1', 'Administrador');
end $$;

-- ===== Grupo 1: administrador de la empresa A =====
do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000000a';
  b constant uuid := '00000000-0000-0000-0000-00000000000b';
  n integer; failed boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
  set local role authenticated;

  select count(*) into n from public.companies;
  if n <> 1 then raise exception 'FALLÓ [1.1]: el administrador A debe ver exactamente 1 empresa y ve %', n; end if;

  select count(*) into n from public.roles where company_id = b;
  if n <> 0 then raise exception 'FALLÓ [1.2]: el administrador A ve roles de la empresa B'; end if;

  select count(*) into n from public.roles where company_id = a;
  if n <> 5 then raise exception 'FALLÓ [1.3]: la empresa A debe tener 5 roles predefinidos y tiene %', n; end if;

  select count(*) into n from public.memberships where company_id = b;
  if n <> 0 then raise exception 'FALLÓ [1.4]: el administrador A ve membresías de la empresa B'; end if;

  select count(*) into n from public.profiles where id = '00000000-0000-0000-0000-0000000000b1';
  if n <> 0 then raise exception 'FALLÓ [1.5]: el administrador A ve el perfil de un usuario de otra empresa'; end if;

  select count(*) into n from public.profiles where id = '00000000-0000-0000-0000-0000000000c1';
  if n <> 1 then raise exception 'FALLÓ [1.6]: el administrador A debe ver el perfil de su compañero'; end if;

  update public.companies set name = 'Hackeada' where id = b;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLÓ [1.7]: el administrador A pudo modificar la empresa B'; end if;

  update public.companies set name = 'Empresa A S.A.S.' where id = a;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLÓ [1.8]: el administrador A no pudo modificar su propia empresa'; end if;

  failed := false;
  begin
    insert into public.roles (company_id, name) values (b, 'Intruso');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [1.9]: el administrador A pudo crear un rol en la empresa B'; end if;

  insert into public.roles (company_id, name) values (a, 'Rol de prueba');

  failed := false;
  begin
    insert into public.memberships (company_id, user_id, role_id, status)
    select b, '00000000-0000-0000-0000-0000000000d1', r.id, 'active' from public.roles r limit 1;
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [1.10]: el administrador A pudo agregar miembros a la empresa B'; end if;

  update public.profiles set full_name = 'Otro nombre' where id = '00000000-0000-0000-0000-0000000000c1';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLÓ [1.11]: pudo editar el perfil de otra persona'; end if;

  update public.profiles set full_name = 'Admin A' where id = '00000000-0000-0000-0000-0000000000a1';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLÓ [1.12]: no pudo editar su propio perfil'; end if;

  select count(*) into n from public.permissions;
  if n <> 10 then raise exception 'FALLÓ [1.13]: el catálogo debe tener 10 permisos y tiene %', n; end if;

  reset role;
end $$;

-- ===== Grupo 2: usuario con rol "Consulta" de la empresa A (solo lectura) =====
do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000000a';
  b constant uuid := '00000000-0000-0000-0000-00000000000b';
  n integer; failed boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
  set local role authenticated;

  select count(*) into n from public.companies;
  if n <> 1 then raise exception 'FALLÓ [2.1]: el usuario Consulta debe ver su empresa'; end if;

  update public.companies set name = 'Cambio indebido' where id = a;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLÓ [2.2]: un usuario Consulta pudo modificar la empresa'; end if;

  update public.company_settings set invitation_valid_days = 30 where company_id = a;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLÓ [2.3]: un usuario Consulta pudo cambiar los ajustes'; end if;

  failed := false;
  begin
    insert into public.roles (company_id, name) values (a, 'Rol indebido');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [2.4]: un usuario Consulta pudo crear un rol'; end if;

  failed := false;
  begin
    insert into public.memberships (company_id, user_id, role_id, status)
    select a, '00000000-0000-0000-0000-0000000000d1', r.id, 'active' from public.roles r where r.company_id = a limit 1;
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [2.5]: un usuario Consulta pudo agregar miembros'; end if;

  if not public.has_permission(a, 'reports.view') then raise exception 'FALLÓ [2.6]: Consulta debe tener reports.view'; end if;
  if public.has_permission(a, 'users.manage') then raise exception 'FALLÓ [2.7]: Consulta no debe tener users.manage'; end if;
  if public.has_permission(b, 'reports.view') then raise exception 'FALLÓ [2.8]: has_permission da acceso en otra empresa'; end if;

  reset role;
end $$;

-- ===== Grupo 3: usuario sin empresa =====
do $$
declare n integer;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000d1', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
  set local role authenticated;

  select count(*) into n from public.companies;
  if n <> 0 then raise exception 'FALLÓ [3.1]: un usuario sin empresa ve empresas'; end if;
  select count(*) into n from public.roles;
  if n <> 0 then raise exception 'FALLÓ [3.2]: un usuario sin empresa ve roles'; end if;
  select count(*) into n from public.memberships;
  if n <> 0 then raise exception 'FALLÓ [3.3]: un usuario sin empresa ve membresías'; end if;

  reset role;
end $$;

-- ===== Grupo 4: visitante anónimo =====
do $$
declare n integer; denied boolean := false;
begin
  set local role anon;
  begin
    select count(*) into n from public.companies;
    if n <> 0 then raise exception 'FALLÓ [4.1]: un visitante anónimo ve empresas'; end if;
  exception when insufficient_privilege then denied := true; end;
  reset role;
end $$;

-- ===== Grupo 5: reglas de negocio (como superadmin) =====
do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000000a';
  b constant uuid := '00000000-0000-0000-0000-00000000000b';
  failed boolean;
begin
  -- No se puede dejar la empresa sin administrador
  failed := false;
  begin
    update public.memberships set status = 'disabled'
    where company_id = a and user_id = '00000000-0000-0000-0000-0000000000a1';
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [5.1]: se pudo desactivar al único administrador'; end if;

  -- No se puede quitar users.manage al único rol administrador
  failed := false;
  begin
    delete from public.role_permissions rp using public.roles r
    where r.id = rp.role_id and r.company_id = a and r.name = 'Administrador' and rp.permission_key = 'users.manage';
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [5.2]: se pudo quitar users.manage al único administrador'; end if;

  -- No se puede eliminar un rol con usuarios
  failed := false;
  begin
    delete from public.roles where company_id = a and name = 'Administrador';
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [5.3]: se pudo eliminar un rol con usuarios'; end if;

  -- No se pueden eliminar roles predefinidos (aunque no tengan usuarios)
  failed := false;
  begin
    delete from public.roles where company_id = b and name = 'Consulta';
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [5.4]: se pudo eliminar un rol predefinido'; end if;

  -- Un miembro no puede tener un rol de otra empresa
  failed := false;
  begin
    insert into public.memberships (company_id, user_id, role_id, status)
    select a, '00000000-0000-0000-0000-0000000000d1', r.id, 'active'
    from public.roles r where r.company_id = b and r.name = 'Consulta';
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [5.5]: se asignó un rol de otra empresa a una membresía'; end if;

  -- Con un segundo administrador, ya se puede desactivar al primero
  update public.memberships set role_id = (select id from public.roles where company_id = a and name = 'Administrador')
  where company_id = a and user_id = '00000000-0000-0000-0000-0000000000c1';
  update public.memberships set status = 'disabled'
  where company_id = a and user_id = '00000000-0000-0000-0000-0000000000a1';

  -- Eliminar una empresa elimina en cascada sus roles, ajustes y membresías
  delete from public.companies where id = b;
  if exists (select 1 from public.roles where company_id = b) then
    raise exception 'FALLÓ [5.6]: al eliminar la empresa quedaron roles huérfanos';
  end if;
end $$;

rollback;

select 'OK: todas las pruebas de la semana 1 pasaron' as resultado;
