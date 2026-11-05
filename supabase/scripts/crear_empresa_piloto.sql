-- ContractOK · Crear la empresa del piloto y su primer administrador
-- Ejecútalo en el Editor SQL de Supabase. Antes:
--   1. En Authentication > Users, invita (Invite user) o agrega (Add user) al administrador del cliente.
--   2. Copia el correo exacto con el que lo creaste.
-- Cambia los valores marcados con TODO y ejecuta.

with nueva as (
  insert into public.companies (name, nit, city)      -- TODO: nombre, NIT y ciudad de tu cliente
  values ('Nombre de la empresa cliente', '900000000-0', 'Bogotá')
  returning id
)
select public.add_member(
  nueva.id,
  (select id from auth.users where email = 'admin@cliente.com'),  -- TODO: correo del administrador
  'Administrador'
) as membership_id
from nueva;

-- Verifica el resultado:
select c.name as empresa, u.email, r.name as rol, m.status
from public.memberships m
join public.companies c on c.id = m.company_id
join auth.users u on u.id = m.user_id
join public.roles r on r.id = m.role_id;
