-- ContractOK · Semana 2 · Seguridad por filas para contratistas

alter table public.contractors enable row level security;
alter table public.contractor_members enable row level security;
alter table public.contractor_assignments enable row level security;
alter table public.workers enable row level security;
alter table public.invitations enable row level security;

-- contractors: el personal ve según sus responsabilidades; el contratista ve solo el suyo.
create policy contractors_select on public.contractors for select to authenticated
  using (public.can_view_contractor(company_id, id) or public.is_contractor_member(id));
create policy contractors_insert on public.contractors for insert to authenticated
  with check (public.has_permission(company_id, 'contractors.manage'));
create policy contractors_update on public.contractors for update to authenticated
  using (public.has_permission(company_id, 'contractors.manage', id))
  with check (public.has_permission(company_id, 'contractors.manage', id));
-- No hay política de borrado: los contratistas se archivan (archived_at).

-- contractor_members: cada quien ve sus propias filas; el personal con contractors.manage ve las de su empresa.
create policy contractor_members_select on public.contractor_members for select to authenticated
  using (
    user_id = (select auth.uid())
    or public.has_permission(public.contractor_company_id(contractor_id), 'contractors.manage', contractor_id)
  );

-- contractor_assignments
create policy contractor_assignments_select on public.contractor_assignments for select to authenticated
  using (
    user_id = (select auth.uid())
    or public.has_permission(public.contractor_company_id(contractor_id), 'contractors.manage', contractor_id)
  );
create policy contractor_assignments_insert on public.contractor_assignments for insert to authenticated
  with check (public.has_permission(public.contractor_company_id(contractor_id), 'contractors.manage'));
create policy contractor_assignments_delete on public.contractor_assignments for delete to authenticated
  using (public.has_permission(public.contractor_company_id(contractor_id), 'contractors.manage'));

-- workers: los gestionan el personal autorizado y el propio contratista.
create policy workers_select on public.workers for select to authenticated
  using (public.can_view_contractor(company_id, contractor_id) or public.is_contractor_member(contractor_id));
create policy workers_insert on public.workers for insert to authenticated
  with check (
    public.has_permission(company_id, 'contractors.manage', contractor_id)
    or public.has_permission(company_id, 'documents.upload_on_behalf', contractor_id)
    or public.is_contractor_member(contractor_id)
  );
create policy workers_update on public.workers for update to authenticated
  using (
    public.has_permission(company_id, 'contractors.manage', contractor_id)
    or public.has_permission(company_id, 'documents.upload_on_behalf', contractor_id)
    or public.is_contractor_member(contractor_id)
  )
  with check (
    public.has_permission(company_id, 'contractors.manage', contractor_id)
    or public.has_permission(company_id, 'documents.upload_on_behalf', contractor_id)
    or public.is_contractor_member(contractor_id)
  );
create policy workers_delete on public.workers for delete to authenticated
  using (
    public.has_permission(company_id, 'contractors.manage', contractor_id)
    or public.has_permission(company_id, 'documents.upload_on_behalf', contractor_id)
    or public.is_contractor_member(contractor_id)
  );

-- invitations: solo lectura para quien gestiona contratistas; se crean y anulan con funciones.
create policy invitations_select on public.invitations for select to authenticated
  using (public.has_permission(company_id, 'contractors.manage', contractor_id));

-- Permisos de tabla
revoke all on public.contractors, public.contractor_members, public.contractor_assignments,
  public.workers, public.invitations from anon;

grant select, insert, update on public.contractors to authenticated;
grant select on public.contractor_members to authenticated;
grant select, insert, delete on public.contractor_assignments to authenticated;
grant select, insert, update, delete on public.workers to authenticated;
-- Invitaciones: se concede lectura de columnas, SIN token_hash.
grant select (id, company_id, contractor_id, email, expires_at, used_at, revoked_at,
              sent_count, last_sent_at, created_by, created_at)
  on public.invitations to authenticated;

grant all on public.contractors, public.contractor_members, public.contractor_assignments,
  public.workers, public.invitations to service_role;

-- Funciones: cerradas por defecto; se abre solo lo necesario.
revoke execute on function
  public.contractor_company_id(uuid), public.is_contractor_member(uuid),
  public.can_view_contractor(uuid, uuid), public.trg_workers_require_company_kind(),
  public.trg_assignments_require_staff()
  from public, anon, authenticated;

grant execute on function
  public.contractor_company_id(uuid), public.is_contractor_member(uuid),
  public.can_view_contractor(uuid, uuid)
  to authenticated;
