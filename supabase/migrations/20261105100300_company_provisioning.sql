-- ContractOK · Semana 1 · Alta de empresas
-- Al insertar una empresa se crean sus ajustes y sus roles predefinidos.

create or replace function public.create_default_roles(p_company_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_admin uuid; v_reviewer uuid; v_supervisor uuid; v_accounting uuid; v_viewer uuid;
begin
  insert into public.roles (company_id, name, description, is_system)
  values (p_company_id, 'Administrador', 'Acceso completo a la configuración y a todos los módulos', true)
  returning id into v_admin;
  insert into public.role_permissions (role_id, permission_key, scope)
  select v_admin, p.key, 'all' from public.permissions p;

  insert into public.roles (company_id, name, description, is_system)
  values (p_company_id, 'Revisor SST', 'Revisa y aprueba documentos y recibe alertas', true)
  returning id into v_reviewer;
  insert into public.role_permissions (role_id, permission_key, scope) values
    (v_reviewer, 'documents.review', 'all'),
    (v_reviewer, 'documents.upload_on_behalf', 'all'),
    (v_reviewer, 'alerts.receive', 'all'),
    (v_reviewer, 'reports.view', 'all');

  insert into public.roles (company_id, name, description, is_system)
  values (p_company_id, 'Supervisor de contrato', 'Valida informes de actividades de los contratos que supervisa', true)
  returning id into v_supervisor;
  insert into public.role_permissions (role_id, permission_key, scope) values
    (v_supervisor, 'reports.activity_validate', 'assigned'),
    (v_supervisor, 'alerts.receive', 'assigned'),
    (v_supervisor, 'reports.view', 'assigned');

  insert into public.roles (company_id, name, description, is_system)
  values (p_company_id, 'Contabilidad', 'Consulta los paquetes mensuales listos para pago', true)
  returning id into v_accounting;
  insert into public.role_permissions (role_id, permission_key, scope) values
    (v_accounting, 'periods.manage', 'all'),
    (v_accounting, 'reports.view', 'all');

  insert into public.roles (company_id, name, description, is_system)
  values (p_company_id, 'Consulta', 'Solo lectura de reportes', true)
  returning id into v_viewer;
  insert into public.role_permissions (role_id, permission_key, scope) values
    (v_viewer, 'reports.view', 'all');
end $$;

create or replace function public.trg_company_defaults()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.company_settings (company_id) values (new.id);
  perform public.create_default_roles(new.id);
  return null;
end $$;

create trigger companies_defaults after insert on public.companies
  for each row execute function public.trg_company_defaults();

-- Agrega a un usuario existente (de Auth) a una empresa con un rol, por nombre del rol.
-- Uso previsto: superadmin desde el editor SQL (el piloto) o desde una Edge Function.
create or replace function public.add_member(
  p_company_id uuid, p_user_id uuid, p_role_name text, p_status text default 'active'
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_role uuid; v_id uuid;
begin
  select r.id into v_role from public.roles r
  where r.company_id = p_company_id and r.name = p_role_name;
  if v_role is null then
    raise exception 'No existe el rol "%" en la empresa', p_role_name using errcode = 'P0002';
  end if;
  insert into public.memberships (company_id, user_id, role_id, status)
  values (p_company_id, p_user_id, v_role, p_status)
  returning id into v_id;
  return v_id;
end $$;
