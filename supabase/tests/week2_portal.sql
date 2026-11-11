-- ContractOK · Semana 2 · Parte 3 · Pruebas del portal del contratista
-- Pega TODO este archivo en el Editor SQL de Supabase (contractok-dev) y ejecútalo. Termina con ROLLBACK (no deja datos).
-- Si algo falla verás un error que empieza con "FALLÓ". Si todo pasa, el último resultado dice OK.

begin;

do $$
begin
  insert into auth.users (id, email) values
    ('00000000-0000-0000-0000-000000000a01', 'admin.a@test.local'),
    ('00000000-0000-0000-0000-000000000c01', 'natural@contratista.com'),
    ('00000000-0000-0000-0000-000000000c02', 'empresa@contratista.com');
  insert into public.companies (id, name) values ('00000000-0000-0000-0000-00000000aaaa', 'Empresa A');
  perform public.add_member('00000000-0000-0000-0000-00000000aaaa', '00000000-0000-0000-0000-000000000a01', 'Administrador');
  insert into public.contractors (id, company_id, kind, display_name, email, status) values
    ('00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000aaaa', 'natural', 'Carlos Natural', 'natural@contratista.com', 'filling'),
    ('00000000-0000-0000-0000-00000000a002', '00000000-0000-0000-0000-00000000aaaa', 'company', 'Empresa Contratista', 'empresa@contratista.com', 'filling');
  insert into public.contractor_members (user_id, contractor_id) values
    ('00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000a001'),
    ('00000000-0000-0000-0000-000000000c02', '00000000-0000-0000-0000-00000000a002');
end $$;

-- Contratista persona natural
do $$
declare r record; failed boolean;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000c01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000c01","role":"authenticated"}', true);
  set local role authenticated;

  perform public.contractor_update_profile('00000000-0000-0000-0000-00000000a001', '  Carlos Natural Pérez  ', ' 1020304050 ', ' 3001234567 ');
  select legal_name, tax_id, phone into r from public.contractors where id = '00000000-0000-0000-0000-00000000a001';
  if r.legal_name <> 'Carlos Natural Pérez' or r.tax_id <> '1020304050' or r.phone <> '3001234567' then
    raise exception 'FALLÓ [1.1]: los datos no se guardaron limpios: %', r;
  end if;

  perform public.contractor_update_profile('00000000-0000-0000-0000-00000000a001', 'Carlos Natural Pérez', '', '');
  select tax_id, phone into r from public.contractors where id = '00000000-0000-0000-0000-00000000a001';
  if r.tax_id is not null or r.phone is not null then raise exception 'FALLÓ [1.2]: los campos vacíos deben guardarse como nulos'; end if;
  perform public.contractor_update_profile('00000000-0000-0000-0000-00000000a001', 'Carlos Natural Pérez', '1020304050', '3001234567');

  failed := false;
  begin perform public.contractor_update_profile('00000000-0000-0000-0000-00000000a002', 'Intruso', '1', '1');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [1.3]: modificó los datos de otro contratista'; end if;

  failed := false;
  begin update public.contractors set status = 'enabled' where id = '00000000-0000-0000-0000-00000000a001';
  exception when others then failed := true; end;
  -- (el UPDATE directo afecta 0 filas por RLS; verificamos que el estado no cambió)
  if (select status from public.contractors where id = '00000000-0000-0000-0000-00000000a001') <> 'filling' then
    raise exception 'FALLÓ [1.4]: el contratista cambió su propio estado';
  end if;
  reset role;
end $$;

-- Un tax_id repetido en la misma empresa se rechaza
do $$
declare failed boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000c02', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000c02","role":"authenticated"}', true);
  set local role authenticated;
  begin perform public.contractor_update_profile('00000000-0000-0000-0000-00000000a002', 'Empresa Contratista S.A.S.', '1020304050', '3109998877');
  exception when unique_violation then failed := true; end;
  if not failed then raise exception 'FALLÓ [2.1]: se repitió el documento de otro contratista de la misma empresa'; end if;
  perform public.contractor_update_profile('00000000-0000-0000-0000-00000000a002', 'Empresa Contratista S.A.S.', '900123456-7', '3109998877');
  reset role;
end $$;

-- El personal de la empresa no usa esta función (no es el contratista)
do $$
declare failed boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000a01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000a01","role":"authenticated"}', true);
  set local role authenticated;
  begin perform public.contractor_update_profile('00000000-0000-0000-0000-00000000a001', 'X', 'X', 'X');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [3.1]: el personal pudo usar la función del contratista'; end if;
  reset role;
end $$;

-- Cuando el estado ya no es de diligenciamiento, no se pueden cambiar los datos
update public.contractors set status = 'enabled' where id = '00000000-0000-0000-0000-00000000a001';
do $$
declare failed boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000c01', true);
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000c01","role":"authenticated"}', true);
  set local role authenticated;
  begin perform public.contractor_update_profile('00000000-0000-0000-0000-00000000a001', 'Nuevo nombre', '1', '1');
  exception when others then failed := true; end;
  if not failed then raise exception 'FALLÓ [4.1]: cambió sus datos estando habilitado'; end if;
  reset role;
end $$;

-- Visitante anónimo
do $$
declare denied boolean := false;
begin
  set local role anon;
  begin perform public.contractor_update_profile('00000000-0000-0000-0000-00000000a001', 'X', 'X', 'X');
  exception when insufficient_privilege then denied := true; end;
  reset role;
  if not denied then raise exception 'FALLÓ [5.1]: un visitante anónimo pudo llamar la función'; end if;
end $$;

rollback;

select 'OK: todas las pruebas del portal pasaron' as resultado;
