-- ContractOK · Semana 3 · Parte 2 · Pruebas del correo en el perfil
-- Pega TODO este archivo en el Editor SQL de Supabase (contractok-dev) y ejecútalo. Termina con ROLLBACK.

begin;

do $$
begin
  insert into auth.users (id, email) values
    ('00000000-0000-0000-0000-000000000a01', 'Admin.A@Test.local'),
    ('00000000-0000-0000-0000-000000000a03', 'consulta.a@test.local'),
    ('00000000-0000-0000-0000-000000000b01', 'admin.b@test.local');
  insert into public.companies (id, name) values
    ('00000000-0000-0000-0000-00000000aaaa', 'Empresa A'),
    ('00000000-0000-0000-0000-00000000bbbb', 'Empresa B');
  perform public.add_member('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-000000000a01', 'Administrador');
  perform public.add_member('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-000000000a03', 'Consulta');
  perform public.add_member('00000000-0000-0000-0000-00000000bbbb', '00000000-0000-0000-0000-000000000b01', 'Administrador');

  if (select email from public.profiles where id = '00000000-0000-0000-0000-000000000a01') <> 'admin.a@test.local' then
    raise exception 'FALLÓ [1.1]: el perfil debe guardar el correo en minúsculas al crearse el usuario';
  end if;
  update auth.users set email = 'admin.nuevo@test.local' where id = '00000000-0000-0000-0000-000000000a01';
  if (select email from public.profiles where id = '00000000-0000-0000-0000-000000000a01') <> 'admin.nuevo@test.local' then
    raise exception 'FALLÓ [1.2]: el perfil debe seguir los cambios de correo de Auth';
  end if;
end $$;

do $$
declare n integer; failed boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000a01","role":"authenticated"}', true);
  set local role authenticated;

  select count(*) into n from public.profiles where email = 'consulta.a@test.local';
  if n <> 1 then raise exception 'FALLÓ [2.1]: el administrador debe ver el correo de su compañero'; end if;
  select count(*) into n from public.profiles where email = 'admin.b@test.local';
  if n <> 0 then raise exception 'FALLÓ [2.2]: ve el correo de alguien de otra empresa'; end if;

  update public.profiles set full_name = 'Nuevo Nombre', job_title = 'Jefe SST' where id = '00000000-0000-0000-0000-000000000a01';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLÓ [2.3]: no pudo editar sus datos personales'; end if;

  failed := false;
  begin update public.profiles set email = 'robado@x.com' where id = '00000000-0000-0000-0000-000000000a01';
  exception when insufficient_privilege then failed := true; end;
  if not failed then raise exception 'FALLÓ [2.4]: pudo cambiar el correo de su perfil'; end if;

  failed := false;
  begin update public.profiles set id = '00000000-0000-0000-0000-000000000a99' where id = '00000000-0000-0000-0000-000000000a01';
  exception when insufficient_privilege then failed := true; end;
  if not failed then raise exception 'FALLÓ [2.5]: pudo cambiar el id de su perfil'; end if;
  reset role;
end $$;

rollback;
select 'OK: todas las pruebas del correo en el perfil pasaron' as resultado;
