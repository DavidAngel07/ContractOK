-- ContractOK · Semana 1 · Funciones auxiliares, reglas de negocio y triggers
-- Las funciones SECURITY DEFINER fijan search_path vacío y usan nombres completos.

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger companies_set_updated_at before update on public.companies
  for each row execute function public.set_updated_at();
create trigger company_settings_set_updated_at before update on public.company_settings
  for each row execute function public.set_updated_at();
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- Empresas a las que pertenece (con membresía activa) el usuario autenticado.
create or replace function public.current_user_company_ids()
returns setof uuid language sql stable security definer set search_path = '' as $$
  select m.company_id
  from public.memberships m
  where m.user_id = (select auth.uid()) and m.status = 'active'
$$;

-- ¿El usuario autenticado tiene esa responsabilidad en la empresa?
-- Sin contratista: basta con tenerla con cualquier alcance.
-- Con contratista: alcance 'all' (el alcance 'assigned' se completa en la semana 2).
create or replace function public.has_permission(
  p_company_id uuid, p_permission text, p_contractor_id uuid default null
)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.memberships m
    join public.role_permissions rp on rp.role_id = m.role_id
    where m.user_id = (select auth.uid())
      and m.company_id = p_company_id
      and m.status = 'active'
      and rp.permission_key = p_permission
      and (p_contractor_id is null or rp.scope = 'all')
  )
$$;

create or replace function public.shares_company_with(p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.memberships a
    join public.memberships b on b.company_id = a.company_id
    where a.user_id = (select auth.uid()) and a.status = 'active'
      and b.user_id = p_user_id
  )
$$;

create or replace function public.role_company_id(p_role_id uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select r.company_id from public.roles r where r.id = p_role_id
$$;

-- Al crearse un usuario en Auth se crea su perfil.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(coalesce(new.email, ''), '@', 1))
  );
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Regla: una empresa siempre conserva al menos un administrador activo
-- (alguien con la responsabilidad users.manage).
create or replace function public.assert_company_has_admin(p_company_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.companies c where c.id = p_company_id) then
    return; -- la empresa se está eliminando
  end if;
  if not exists (
    select 1
    from public.memberships m
    join public.role_permissions rp on rp.role_id = m.role_id
    where m.company_id = p_company_id and m.status = 'active'
      and rp.permission_key = 'users.manage'
  ) then
    raise exception 'La empresa debe conservar al menos un administrador activo con permiso para gestionar usuarios'
      using errcode = '23514';
  end if;
end $$;

create or replace function public.trg_memberships_keep_admin()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'active' and exists (
    select 1 from public.role_permissions rp
    where rp.role_id = old.role_id and rp.permission_key = 'users.manage'
  ) then
    perform public.assert_company_has_admin(old.company_id);
  end if;
  return null;
end $$;

create trigger memberships_keep_admin after update or delete on public.memberships
  for each row execute function public.trg_memberships_keep_admin();

create or replace function public.trg_role_permissions_keep_admin()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_company uuid;
begin
  if old.permission_key = 'users.manage' then
    select r.company_id into v_company from public.roles r where r.id = old.role_id;
    if v_company is not null then
      perform public.assert_company_has_admin(v_company);
    end if;
  end if;
  return null;
end $$;

create trigger role_permissions_keep_admin after update or delete on public.role_permissions
  for each row execute function public.trg_role_permissions_keep_admin();

-- Regla: los roles del sistema no se pueden eliminar.
create or replace function public.trg_roles_protect_system()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.is_system and exists (select 1 from public.companies c where c.id = old.company_id) then
    raise exception 'Los roles predefinidos no se pueden eliminar' using errcode = '23514';
  end if;
  return old;
end $$;

create trigger roles_protect_system before delete on public.roles
  for each row execute function public.trg_roles_protect_system();
