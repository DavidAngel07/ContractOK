-- ContractOK · Semana 4 · Parte 1 · Pruebas del almacenamiento privado de archivos
-- Pega TODO este archivo en el Editor SQL de Supabase (contractok-dev) y ejecútalo. Termina con ROLLBACK (no deja datos).
-- Comprueba quién puede subir y quién puede leer archivos del bucket «documents», según la ruta <empresa>/<contratista>/<archivo>.
-- Si algo falla verás un error que empieza con "FALLÓ". Si todo pasa, el último resultado dice OK.

begin;

create function public.tt_act(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

create function public.tt_put(p_name text) returns text language plpgsql as $$
begin
  insert into storage.objects (bucket_id, name) values ('documents', p_name);
  return 'OK';
exception when others then return sqlstate;
end $$;

do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000aaaa';
  b constant uuid := '00000000-0000-0000-0000-00000000bbbb';
  n constant uuid := '00000000-0000-0000-0000-00000000a001';
  k constant uuid := '00000000-0000-0000-0000-00000000a002';
  bk constant uuid := '00000000-0000-0000-0000-00000000b001';
begin
  if not exists (select 1 from storage.buckets where id = 'documents' and public = false and file_size_limit = 10485760) then
    raise exception 'FALLÓ [0.1]: el bucket «documents» debe existir, ser privado y limitado a 10 MB';
  end if;
  insert into auth.users (id, email) values
    ('00000000-0000-0000-0000-000000000a01', 'admin.a@test.local'),
    ('00000000-0000-0000-0000-000000000a02', 'revisor.a@test.local'),
    ('00000000-0000-0000-0000-000000000a03', 'consulta.a@test.local'),
    ('00000000-0000-0000-0000-000000000b01', 'admin.b@test.local'),
    ('00000000-0000-0000-0000-000000000c01', 'natural@contratista.com'),
    ('00000000-0000-0000-0000-000000000c02', 'empresa@contratista.com'),
    ('00000000-0000-0000-0000-000000000c03', 'otra@contratista.com');
  insert into public.companies (id, name) values (a, 'Empresa A'), (b, 'Empresa B');
  perform public.add_member(a, '00000000-0000-0000-0000-000000000a01', 'Administrador');
  perform public.add_member(a, '00000000-0000-0000-0000-000000000a02', 'Revisor SST');
  perform public.add_member(a, '00000000-0000-0000-0000-000000000a03', 'Consulta');
  perform public.add_member(b, '00000000-0000-0000-0000-000000000b01', 'Administrador');
  insert into public.contractors (id, company_id, kind, display_name, email) values
    (n, a, 'natural', 'Carlos Natural', 'natural@contratista.com'),
    (k, a, 'company', 'Empresa K', 'empresa@contratista.com'),
    (bk, b, 'company', 'Contratista B', 'otra@contratista.com');
  insert into public.contractor_members (user_id, contractor_id) values
    ('00000000-0000-0000-0000-000000000c01', n), ('00000000-0000-0000-0000-000000000c02', k), ('00000000-0000-0000-0000-000000000c03', bk);
end $$;

do $$
declare
  a text := '00000000-0000-0000-0000-00000000aaaa';
  b text := '00000000-0000-0000-0000-00000000bbbb';
  n text := '00000000-0000-0000-0000-00000000a001';
  k text := '00000000-0000-0000-0000-00000000a002';
  cnt integer; failed boolean;
begin
  -- El contratista sube solo en su carpeta
  perform public.tt_act('00000000-0000-0000-0000-000000000c01');
  if public.tt_put(a || '/' || n || '/rut.pdf') <> 'OK' then raise exception 'FALLÓ [1.1]: el contratista no pudo subir a su carpeta'; end if;
  if public.tt_put(a || '/' || k || '/rut.pdf') = 'OK' then raise exception 'FALLÓ [1.2]: subió a la carpeta de otro contratista'; end if;
  if public.tt_put(b || '/' || n || '/rut.pdf') = 'OK' then raise exception 'FALLÓ [1.3]: usó una empresa que no corresponde a su contratista'; end if;
  if public.tt_put(a || '/' || n) = 'OK' then raise exception 'FALLÓ [1.4]: aceptó una ruta sin nombre de archivo'; end if;
  if public.tt_put('basura/' || n || '/x.pdf') = 'OK' then raise exception 'FALLÓ [1.5]: aceptó una ruta con empresa inválida'; end if;
  if public.tt_put(a || '/basura/x.pdf') = 'OK' then raise exception 'FALLÓ [1.6]: aceptó una ruta con contratista inválido'; end if;
  select count(*) into cnt from storage.objects;
  if cnt <> 1 then raise exception 'FALLÓ [1.7]: el contratista debe ver solo su archivo y ve %', cnt; end if;
  failed := false;
  begin update storage.objects set name = name || 'x'; get diagnostics cnt = row_count; if cnt = 0 then failed := true; end if;
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [1.8]: el contratista pudo renombrar archivos'; end if;
  begin delete from storage.objects; get diagnostics cnt = row_count; if cnt = 0 then failed := true; end if;
  exception when others then failed := true; end;
  reset role;
  select count(*) into cnt from storage.objects;
  if cnt <> 1 then raise exception 'FALLÓ [1.9]: el contratista pudo borrar archivos'; end if;

  -- Personal con carga asistida; solo lectura puede ver pero no subir
  perform public.tt_act('00000000-0000-0000-0000-000000000a02');
  if public.tt_put(a || '/' || k || '/cedula.pdf') <> 'OK' then raise exception 'FALLÓ [2.1]: el revisor no pudo subir en nombre del contratista'; end if;
  select count(*) into cnt from storage.objects;
  if cnt <> 2 then raise exception 'FALLÓ [2.2]: el revisor debe ver los 2 archivos de su empresa y ve %', cnt; end if;
  reset role;
  perform public.tt_act('00000000-0000-0000-0000-000000000a03');
  if public.tt_put(a || '/' || n || '/otro.pdf') = 'OK' then raise exception 'FALLÓ [2.3]: un rol de solo lectura pudo subir archivos'; end if;
  select count(*) into cnt from storage.objects;
  if cnt <> 2 then raise exception 'FALLÓ [2.4]: un rol de solo lectura debe poder ver los archivos y ve %', cnt; end if;
  reset role;

  -- Otros contratistas, otra empresa y visitantes no ven nada ajeno
  perform public.tt_act('00000000-0000-0000-0000-000000000c02');
  select count(*) into cnt from storage.objects;
  if cnt <> 1 then raise exception 'FALLÓ [3.1]: el contratista K debe ver solo su archivo y ve %', cnt; end if;
  reset role;
  perform public.tt_act('00000000-0000-0000-0000-000000000c03');
  select count(*) into cnt from storage.objects;
  if cnt <> 0 then raise exception 'FALLÓ [3.2]: un contratista de otra empresa ve archivos ajenos'; end if;
  reset role;
  perform public.tt_act('00000000-0000-0000-0000-000000000b01');
  select count(*) into cnt from storage.objects;
  if cnt <> 0 then raise exception 'FALLÓ [3.3]: el administrador de otra empresa ve archivos ajenos'; end if;
  if public.tt_put(a || '/' || n || '/intruso.pdf') = 'OK' then raise exception 'FALLÓ [3.4]: el personal de otra empresa pudo subir archivos'; end if;
  reset role;
  set local role anon;
  failed := false;
  begin perform count(*) from storage.objects; exception when insufficient_privilege then failed := true; end;
  reset role;
  if not failed then
    -- Si no falla por privilegios, no debe devolver filas
    set local role anon; select count(*) into cnt from storage.objects; reset role;
    if cnt <> 0 then raise exception 'FALLÓ [3.5]: un visitante anónimo ve archivos'; end if;
  end if;
end $$;

rollback;

select 'OK: todas las pruebas del almacenamiento de archivos (semana 4) pasaron' as resultado;
