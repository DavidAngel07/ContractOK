-- ContractOK · Semana 3 · Invitación del personal de la empresa
-- El administrador indica correo y rol. La persona entra con un código a su correo (sin contraseñas)
-- y, al ingresar, su invitación se activa si el correo coincide.

create table public.staff_invitations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  email text not null check (position('@' in email) > 1),
  role_id uuid not null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'revoked')),
  invited_by uuid default auth.uid() references auth.users (id) on delete set null,
  expires_at timestamptz not null default now() + interval '30 days',
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  accepted_by uuid references auth.users (id) on delete set null,
  foreign key (role_id, company_id) references public.roles (id, company_id) on delete cascade,
  foreign key (company_id) references public.companies (id) on delete cascade
);
create unique index staff_invitations_pending_uidx
  on public.staff_invitations (company_id, lower(email)) where status = 'pending';
create index staff_invitations_email_idx on public.staff_invitations (lower(email)) where status = 'pending';

alter table public.staff_invitations enable row level security;
create policy staff_invitations_select on public.staff_invitations for select to authenticated
  using (public.has_permission(company_id, 'users.manage'));
revoke all on public.staff_invitations from anon;
grant select on public.staff_invitations to authenticated;
grant all on public.staff_invitations to service_role;

create or replace function public.invite_staff(p_company_id uuid, p_email text, p_role_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_email text := lower(trim(p_email)); v_id uuid;
begin
  if not public.has_permission(p_company_id, 'users.manage') then
    raise exception 'No tienes permiso para invitar usuarios' using errcode = '42501';
  end if;
  if position('@' in v_email) < 2 then
    raise exception 'Correo no válido' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.memberships m join auth.users u on u.id = m.user_id
    where m.company_id = p_company_id and lower(u.email) = v_email and m.status = 'active'
  ) then
    raise exception 'Esa persona ya pertenece a la empresa' using errcode = '23505';
  end if;
  -- Una sola invitación pendiente por correo: la anterior se anula.
  update public.staff_invitations set status = 'revoked'
  where company_id = p_company_id and lower(email) = v_email and status = 'pending';
  insert into public.staff_invitations (company_id, email, role_id)
  values (p_company_id, v_email, p_role_id)
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.revoke_staff_invitation(p_invitation_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_company uuid;
begin
  select i.company_id into v_company from public.staff_invitations i where i.id = p_invitation_id;
  if v_company is null then
    raise exception 'Invitación no encontrada' using errcode = 'P0002';
  end if;
  if not public.has_permission(v_company, 'users.manage') then
    raise exception 'No tienes permiso para anular esta invitación' using errcode = '42501';
  end if;
  update public.staff_invitations set status = 'revoked' where id = p_invitation_id and status = 'pending';
end $$;

-- Se llama al ingresar: activa las invitaciones pendientes que coincidan con el correo de la sesión.
create or replace function public.claim_staff_invitation()
returns integer language plpgsql security definer set search_path = '' as $$
declare v_user uuid := (select auth.uid()); v_email text; r record; n integer := 0;
begin
  if v_user is null then
    raise exception 'Debes iniciar sesión' using errcode = '28000';
  end if;
  select lower(u.email) into v_email from auth.users u where u.id = v_user;
  if v_email is null then return 0; end if;
  for r in
    select * from public.staff_invitations i
    where i.status = 'pending' and lower(i.email) = v_email and i.expires_at > now()
    for update
  loop
    insert into public.memberships (company_id, user_id, role_id, status, invited_by)
    values (r.company_id, v_user, r.role_id, 'active', r.invited_by)
    on conflict (company_id, user_id) do update set role_id = excluded.role_id, status = 'active';
    update public.staff_invitations
    set status = 'accepted', accepted_at = now(), accepted_by = v_user where id = r.id;
    n := n + 1;
  end loop;
  return n;
end $$;

revoke execute on function public.invite_staff(uuid, text, uuid), public.revoke_staff_invitation(uuid),
  public.claim_staff_invitation() from public, anon, authenticated;
grant execute on function public.invite_staff(uuid, text, uuid), public.revoke_staff_invitation(uuid),
  public.claim_staff_invitation() to authenticated;
