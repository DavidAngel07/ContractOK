-- ContractOK · Crear la empresa del piloto y su primer administrador
-- Ejecútalo en el Editor SQL de Supabase. Antes:
--   1. En Authentication > Users, crea (Add user) o invita al administrador de la empresa.
--   2. Copia el correo exacto con el que lo creaste.
-- Cambia SOLO los 4 valores marcados con TODO y ejecuta todo el script.

do $$
declare
  v_nombre  text := 'ContractOK';        -- TODO: nombre de la empresa
  v_nit     text := '900000000-0';                 -- TODO: NIT
  v_ciudad  text := 'Bogotá';                      -- TODO: ciudad
  v_correo  text := 'dangel.cr29@gmail.com';           -- TODO: correo del administrador (ya creado en Authentication)
  v_user    uuid;
  v_company uuid;
begin
  select id into v_user from auth.users where email = v_correo;
  if v_user is null then
    raise exception 'No existe un usuario con el correo "%" en Authentication > Users. Créalo primero.', v_correo;
  end if;

  -- Al insertar la empresa se crean sus ajustes y sus 5 roles predefinidos.
  insert into public.companies (name, nit, city)
  values (v_nombre, v_nit, v_ciudad)
  returning id into v_company;

  perform public.add_member(v_company, v_user, 'Administrador');
end $$;

-- Verificación: debe mostrar una fila con tu empresa, el correo, el rol Administrador y estado active.
select c.name as empresa, u.email, r.name as rol, m.status
from public.memberships m
join public.companies c on c.id = m.company_id
join auth.users u on u.id = m.user_id
join public.roles r on r.id = m.role_id
order by c.created_at desc;