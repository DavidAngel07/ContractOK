-- ContractOK · Semana 2 · Funciones auxiliares y reglas

create trigger contractors_set_updated_at before update on public.contractors
  for each row execute function public.set_updated_at();

create or replace function public.contractor_company_id(p_contractor_id uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select c.company_id from public.contractors c where c.id = p_contractor_id
$$;

create or replace function public.is_contractor_member(p_contractor_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.contractor_members cm
    where cm.user_id = (select auth.uid()) and cm.contractor_id = p_contractor_id
  )
$$;

-- Reemplaza la versión de la semana 1: ahora entiende el alcance "assigned".
-- Con contratista: alcance "all", o "assigned" si el usuario está asignado a ese contratista.
-- Sin contratista: basta con tener la responsabilidad con cualquier alcance.
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
      and (
        p_contractor_id is null
        or rp.scope = 'all'
        or (rp.scope = 'assigned' and exists (
              select 1 from public.contractor_assignments ca
              where ca.contractor_id = p_contractor_id and ca.user_id = m.user_id))
      )
  )
$$;

-- ¿Puede el personal ver a este contratista? (cualquier responsabilidad relacionada)
create or replace function public.can_view_contractor(p_company_id uuid, p_contractor_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(bool_or(public.has_permission(p_company_id, k, p_contractor_id)), false)
  from unnest(array[
    'contractors.manage', 'documents.review', 'documents.upload_on_behalf', 'reports.view',
    'reports.activity_validate', 'periods.manage', 'alerts.receive'
  ]) as k
$$;

-- Solo las empresas contratistas (kind = company) tienen trabajadores.
create or replace function public.trg_workers_require_company_kind()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.contractors c where c.id = new.contractor_id and c.kind = 'company'
  ) then
    raise exception 'Solo los contratistas de tipo empresa pueden tener trabajadores' using errcode = '23514';
  end if;
  return new;
end $$;

create trigger workers_require_company_kind before insert or update of contractor_id on public.workers
  for each row execute function public.trg_workers_require_company_kind();

-- La persona asignada debe ser personal activo de la empresa del contratista.
create or replace function public.trg_assignments_require_staff()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.memberships m
    join public.contractors c on c.company_id = m.company_id
    where c.id = new.contractor_id and m.user_id = new.user_id and m.status = 'active'
  ) then
    raise exception 'Solo se puede asignar personal activo de la misma empresa' using errcode = '23514';
  end if;
  return new;
end $$;

create trigger assignments_require_staff before insert or update on public.contractor_assignments
  for each row execute function public.trg_assignments_require_staff();
