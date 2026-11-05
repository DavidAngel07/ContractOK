-- ContractOK · Semana 1 · Seguridad por filas (RLS) y permisos de acceso
-- Con "Automatically expose new tables" desactivado, cada tabla necesita GRANT explícito.

alter table public.companies enable row level security;
alter table public.company_settings enable row level security;
alter table public.profiles enable row level security;
alter table public.permissions enable row level security;
alter table public.roles enable row level security;
alter table public.role_permissions enable row level security;
alter table public.memberships enable row level security;

-- companies
create policy companies_select on public.companies for select to authenticated
  using (id in (select public.current_user_company_ids()));
create policy companies_update on public.companies for update to authenticated
  using (public.has_permission(id, 'company.configure'))
  with check (public.has_permission(id, 'company.configure'));

-- company_settings
create policy company_settings_select on public.company_settings for select to authenticated
  using (company_id in (select public.current_user_company_ids()));
create policy company_settings_update on public.company_settings for update to authenticated
  using (public.has_permission(company_id, 'company.configure'))
  with check (public.has_permission(company_id, 'company.configure'));

-- profiles: el propio y los de quienes comparten empresa
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or public.shares_company_with(id));
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- permissions: catálogo de solo lectura
create policy permissions_select on public.permissions for select to authenticated
  using (true);

-- roles
create policy roles_select on public.roles for select to authenticated
  using (company_id in (select public.current_user_company_ids()));
create policy roles_insert on public.roles for insert to authenticated
  with check (public.has_permission(company_id, 'users.manage'));
create policy roles_update on public.roles for update to authenticated
  using (public.has_permission(company_id, 'users.manage'))
  with check (public.has_permission(company_id, 'users.manage'));
create policy roles_delete on public.roles for delete to authenticated
  using (public.has_permission(company_id, 'users.manage'));

-- role_permissions
create policy role_permissions_select on public.role_permissions for select to authenticated
  using (public.role_company_id(role_id) in (select public.current_user_company_ids()));
create policy role_permissions_insert on public.role_permissions for insert to authenticated
  with check (public.has_permission(public.role_company_id(role_id), 'users.manage'));
create policy role_permissions_update on public.role_permissions for update to authenticated
  using (public.has_permission(public.role_company_id(role_id), 'users.manage'))
  with check (public.has_permission(public.role_company_id(role_id), 'users.manage'));
create policy role_permissions_delete on public.role_permissions for delete to authenticated
  using (public.has_permission(public.role_company_id(role_id), 'users.manage'));

-- memberships
create policy memberships_select on public.memberships for select to authenticated
  using (company_id in (select public.current_user_company_ids()));
create policy memberships_insert on public.memberships for insert to authenticated
  with check (public.has_permission(company_id, 'users.manage'));
create policy memberships_update on public.memberships for update to authenticated
  using (public.has_permission(company_id, 'users.manage'))
  with check (public.has_permission(company_id, 'users.manage'));
create policy memberships_delete on public.memberships for delete to authenticated
  using (public.has_permission(company_id, 'users.manage'));

-- Permisos de tabla (el anónimo no tiene acceso a nada)
revoke all on public.companies, public.company_settings, public.profiles, public.permissions,
  public.roles, public.role_permissions, public.memberships from anon;

grant select, update on public.companies to authenticated;
grant select, update on public.company_settings to authenticated;
grant select, update on public.profiles to authenticated;
grant select on public.permissions to authenticated;
grant select, insert, update, delete on public.roles to authenticated;
grant select, insert, update, delete on public.role_permissions to authenticated;
grant select, insert, update, delete on public.memberships to authenticated;
grant all on public.companies, public.company_settings, public.profiles, public.permissions,
  public.roles, public.role_permissions, public.memberships to service_role;

-- Funciones: nada es ejecutable por defecto; se abre solo lo necesario.
revoke execute on function
  public.set_updated_at(), public.handle_new_user(), public.assert_company_has_admin(uuid),
  public.trg_memberships_keep_admin(), public.trg_role_permissions_keep_admin(),
  public.trg_roles_protect_system(), public.create_default_roles(uuid),
  public.trg_company_defaults(), public.add_member(uuid, uuid, text, text),
  public.current_user_company_ids(), public.has_permission(uuid, text, uuid),
  public.shares_company_with(uuid), public.role_company_id(uuid)
  from public, anon, authenticated;

grant execute on function
  public.current_user_company_ids(), public.has_permission(uuid, text, uuid),
  public.shares_company_with(uuid), public.role_company_id(uuid)
  to authenticated;

grant execute on function public.add_member(uuid, uuid, text, text) to service_role;
