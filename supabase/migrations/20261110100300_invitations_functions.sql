-- ContractOK · Semana 2 · Invitaciones: crear, anular, previsualizar y reclamar
-- El token se entrega UNA sola vez a quien invita; en la base solo se guarda su hash (SHA-256).

create or replace function public.create_invitation(p_contractor_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_company uuid; v_email text; v_days integer; v_token text; v_exp timestamptz;
begin
  select c.company_id, c.email into v_company, v_email
  from public.contractors c where c.id = p_contractor_id and c.archived_at is null;
  if v_company is null then
    raise exception 'Contratista no encontrado' using errcode = 'P0002';
  end if;
  if not public.has_permission(v_company, 'contractors.manage', p_contractor_id) then
    raise exception 'No tienes permiso para invitar a este contratista' using errcode = '42501';
  end if;

  select s.invitation_valid_days into v_days from public.company_settings s where s.company_id = v_company;

  -- Una sola invitación vigente por contratista: las anteriores sin usar se anulan.
  update public.invitations set revoked_at = now()
  where contractor_id = p_contractor_id and used_at is null and revoked_at is null;

  v_token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  v_exp := now() + make_interval(days => coalesce(v_days, 7));

  insert into public.invitations (company_id, contractor_id, email, token_hash, expires_at, created_by)
  values (v_company, p_contractor_id, v_email,
          encode(sha256(convert_to(v_token, 'UTF8')), 'hex'), v_exp, (select auth.uid()));

  return jsonb_build_object('token', v_token, 'expires_at', v_exp);
end $$;

create or replace function public.revoke_invitation(p_invitation_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_company uuid; v_contractor uuid;
begin
  select i.company_id, i.contractor_id into v_company, v_contractor
  from public.invitations i where i.id = p_invitation_id;
  if v_company is null then
    raise exception 'Invitación no encontrada' using errcode = 'P0002';
  end if;
  if not public.has_permission(v_company, 'contractors.manage', v_contractor) then
    raise exception 'No tienes permiso para anular esta invitación' using errcode = '42501';
  end if;
  update public.invitations set revoked_at = coalesce(revoked_at, now()) where id = p_invitation_id;
end $$;

-- Vista previa pública del enlace (sin sesión): no revela más que lo necesario.
create or replace function public.get_invitation_preview(p_token text)
returns table (state text, company_name text, contractor_name text, email_hint text)
language plpgsql stable security definer set search_path = '' as $$
declare v_inv public.invitations%rowtype;
begin
  select * into v_inv from public.invitations i
  where i.token_hash = encode(sha256(convert_to(coalesce(p_token, ''), 'UTF8')), 'hex');
  if not found then
    return query select 'invalid'::text, null::text, null::text, null::text;
    return;
  end if;
  return query
  select
    case
      when v_inv.revoked_at is not null then 'revoked'
      when v_inv.used_at is not null then 'used'
      when v_inv.expires_at < now() then 'expired'
      else 'valid'
    end,
    (select co.name from public.companies co where co.id = v_inv.company_id),
    (select c.display_name from public.contractors c where c.id = v_inv.contractor_id),
    left(v_inv.email, 1) || '***@' || split_part(v_inv.email, '@', 2);
end $$;

-- El contratista, ya autenticado por código al correo, reclama su invitación.
-- Se exige: token válido Y que el correo de la sesión sea el de la invitación.
create or replace function public.claim_invitation(p_token text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_inv public.invitations%rowtype; v_user uuid := (select auth.uid()); v_email text;
begin
  if v_user is null then
    raise exception 'Debes iniciar sesión' using errcode = '28000';
  end if;
  select * into v_inv from public.invitations i
  where i.token_hash = encode(sha256(convert_to(coalesce(p_token, ''), 'UTF8')), 'hex');
  if not found then
    raise exception 'Invitación no válida' using errcode = 'P0002';
  end if;
  if v_inv.revoked_at is not null then
    raise exception 'La invitación fue anulada' using errcode = '42501';
  end if;
  if v_inv.expires_at < now() then
    raise exception 'La invitación venció' using errcode = '42501';
  end if;
  select lower(u.email) into v_email from auth.users u where u.id = v_user;
  if v_email is null or v_email <> lower(v_inv.email) then
    raise exception 'Esta invitación es para otro correo' using errcode = '42501';
  end if;
  if v_inv.used_at is not null and not exists (
    select 1 from public.contractor_members cm
    where cm.user_id = v_user and cm.contractor_id = v_inv.contractor_id
  ) then
    raise exception 'La invitación ya fue usada' using errcode = '42501';
  end if;

  insert into public.contractor_members (user_id, contractor_id)
  values (v_user, v_inv.contractor_id) on conflict do nothing;
  update public.invitations set used_at = coalesce(used_at, now()) where id = v_inv.id;
  update public.contractors set status = 'filling' where id = v_inv.contractor_id and status = 'invited';
  return v_inv.contractor_id;
end $$;

-- Contexto del portal: a qué contratistas (y de qué empresa) pertenece el usuario autenticado.
create or replace function public.my_contractor_portal()
returns table (contractor_id uuid, display_name text, kind text, status text, company_id uuid, company_name text)
language sql stable security definer set search_path = '' as $$
  select c.id, c.display_name, c.kind, c.status, co.id, co.name
  from public.contractor_members cm
  join public.contractors c on c.id = cm.contractor_id
  join public.companies co on co.id = c.company_id
  where cm.user_id = (select auth.uid()) and c.archived_at is null
$$;

revoke execute on function
  public.create_invitation(uuid), public.revoke_invitation(uuid), public.get_invitation_preview(text),
  public.claim_invitation(text), public.my_contractor_portal()
  from public, anon, authenticated;

grant execute on function
  public.create_invitation(uuid), public.revoke_invitation(uuid), public.claim_invitation(text),
  public.my_contractor_portal()
  to authenticated;
grant execute on function public.get_invitation_preview(text) to anon, authenticated;
