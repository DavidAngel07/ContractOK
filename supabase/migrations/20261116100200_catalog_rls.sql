-- ContractOK · Semana 3 · Seguridad por filas del catálogo y los perfiles

alter table public.document_types enable row level security;
alter table public.requirement_profiles enable row level security;
alter table public.requirement_profile_items enable row level security;

-- Todo el personal de la empresa puede leer; solo quien configura la empresa puede modificar.
create policy document_types_select on public.document_types for select to authenticated
  using (company_id in (select public.current_user_company_ids()));
create policy document_types_insert on public.document_types for insert to authenticated
  with check (public.has_permission(company_id, 'company.configure'));
create policy document_types_update on public.document_types for update to authenticated
  using (public.has_permission(company_id, 'company.configure'))
  with check (public.has_permission(company_id, 'company.configure'));
create policy document_types_delete on public.document_types for delete to authenticated
  using (public.has_permission(company_id, 'company.configure'));

create policy requirement_profiles_select on public.requirement_profiles for select to authenticated
  using (company_id in (select public.current_user_company_ids()));
create policy requirement_profiles_insert on public.requirement_profiles for insert to authenticated
  with check (public.has_permission(company_id, 'company.configure'));
create policy requirement_profiles_update on public.requirement_profiles for update to authenticated
  using (public.has_permission(company_id, 'company.configure'))
  with check (public.has_permission(company_id, 'company.configure'));
create policy requirement_profiles_delete on public.requirement_profiles for delete to authenticated
  using (public.has_permission(company_id, 'company.configure'));

create policy requirement_profile_items_select on public.requirement_profile_items for select to authenticated
  using (company_id in (select public.current_user_company_ids()));
create policy requirement_profile_items_insert on public.requirement_profile_items for insert to authenticated
  with check (public.has_permission(company_id, 'company.configure'));
create policy requirement_profile_items_update on public.requirement_profile_items for update to authenticated
  using (public.has_permission(company_id, 'company.configure'))
  with check (public.has_permission(company_id, 'company.configure'));
create policy requirement_profile_items_delete on public.requirement_profile_items for delete to authenticated
  using (public.has_permission(company_id, 'company.configure'));

revoke all on public.document_types, public.requirement_profiles, public.requirement_profile_items from anon;
grant select, insert, update, delete on public.document_types to authenticated;
grant select, insert, update, delete on public.requirement_profiles to authenticated;
grant select, insert, update, delete on public.requirement_profile_items to authenticated;
grant all on public.document_types, public.requirement_profiles, public.requirement_profile_items to service_role;
