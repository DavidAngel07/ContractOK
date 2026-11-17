-- ContractOK · Semana 4 · Parte 1 · Reglas de subida, revisión y estado de los requisitos

-- ---------- Validaciones al subir ----------
create or replace function public.trg_documents_before_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  t public.document_types%rowtype;
  c record;
  v_zero constant uuid := '00000000-0000-0000-0000-000000000000';
begin
  select * into t from public.document_types where id = new.document_type_id and company_id = new.company_id;
  if not found then raise exception 'Tipo de documento no encontrado' using errcode = 'P0002'; end if;
  if not t.is_active then raise exception 'Este documento está desactivado' using errcode = '23514'; end if;
  if t.scope <> 'contractor' then
    raise exception 'Este documento se carga por contrato; esa opción se habilita más adelante' using errcode = '23514';
  end if;

  select k.kind, k.status, k.archived_at, k.requirement_profile_id into c
  from public.contractors k where k.id = new.contractor_id and k.company_id = new.company_id;
  if not found or c.archived_at is not null then raise exception 'Contratista no encontrado' using errcode = 'P0002'; end if;
  if c.status = 'closed' then raise exception 'El contrato de este contratista está cerrado' using errcode = '23514'; end if;
  if c.requirement_profile_id is null or not exists (
    select 1 from public.requirement_profile_items i
    where i.requirement_profile_id = c.requirement_profile_id and i.document_type_id = t.id
  ) then
    raise exception 'El documento no está en el perfil de requisitos de este contratista' using errcode = '23514';
  end if;

  -- ¿De quién es? Los de trabajador son de cada trabajador (empresa contratista) o del propio contratista (persona natural).
  if t.owner_kind = 'worker' and c.kind = 'company' then
    if new.worker_id is null then raise exception 'Indica a qué trabajador corresponde' using errcode = '23514'; end if;
    if not exists (
      select 1 from public.workers w
      where w.id = new.worker_id and w.contractor_id = new.contractor_id and w.status = 'active'
    ) then
      raise exception 'El trabajador no existe o está inactivo' using errcode = '23514';
    end if;
  elsif new.worker_id is not null then
    raise exception 'Este documento no corresponde a un trabajador' using errcode = '23514';
  end if;

  -- Fechas declaradas por quien sube el archivo
  if new.declared_issued_on is not null and new.declared_issued_on > current_date then
    raise exception 'La fecha de emisión no puede ser futura' using errcode = '23514';
  end if;
  if t.requires_dates and new.declared_issued_on is null then
    raise exception 'Falta la fecha de emisión' using errcode = '23514';
  end if;
  if t.periodicity = 'expiring' and new.declared_expires_on is null then
    raise exception 'Falta la fecha de vencimiento' using errcode = '23514';
  end if;
  if new.declared_issued_on is not null and new.declared_expires_on is not null
     and new.declared_expires_on < new.declared_issued_on then
    raise exception 'La fecha de vencimiento no puede ser anterior a la de emisión' using errcode = '23514';
  end if;

  -- Un archivo nuevo reemplaza al que estaba pendiente de revisión para el mismo requisito.
  with r as (
    update public.documents d set status = 'replaced'
    where d.contractor_id = new.contractor_id and d.document_type_id = new.document_type_id
      and coalesce(d.worker_id, v_zero) = coalesce(new.worker_id, v_zero) and d.status = 'in_review'
    returning d.id, d.company_id, d.contractor_id
  )
  insert into public.document_events (company_id, contractor_id, document_id, event_type, actor_user_id, data)
  select r.company_id, r.contractor_id, r.id, 'replaced', (select auth.uid()), '{"by":"new_upload"}'::jsonb from r;

  select coalesce(max(d.version), 0) + 1 into new.version from public.documents d
  where d.contractor_id = new.contractor_id and d.document_type_id = new.document_type_id
    and coalesce(d.worker_id, v_zero) = coalesce(new.worker_id, v_zero);

  -- Lo que decide la revisión nunca viene del cliente.
  new.status := 'in_review';
  new.issued_on := null;
  new.expires_on := null;
  new.rejection_reason := null;
  new.rejection_note := null;
  new.reviewed_by := null;
  new.reviewed_at := null;
  new.extracted_data := null;
  new.ai_confidence := null;
  new.uploaded_by := (select auth.uid());
  return new;
end $$;

create trigger documents_before_insert before insert on public.documents
  for each row execute function public.trg_documents_before_insert();

create or replace function public.trg_documents_after_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.document_events (company_id, contractor_id, document_id, event_type, actor_user_id, data)
  values (new.company_id, new.contractor_id, new.id, 'uploaded', new.uploaded_by,
          jsonb_build_object('version', new.version, 'via', new.uploaded_via, 'file_name', new.file_name));
  return null;
end $$;

create trigger documents_after_insert after insert on public.documents
  for each row execute function public.trg_documents_after_insert();

-- ---------- Revisión: aprobar o rechazar ----------
create or replace function public.review_document(
  p_document_id uuid, p_decision text,
  p_issued_on date default null, p_expires_on date default null, p_doc_number text default null,
  p_reason text default null, p_note text default null
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  d public.documents%rowtype;
  t public.document_types%rowtype;
  v_issued date; v_expires date;
  v_zero constant uuid := '00000000-0000-0000-0000-000000000000';
begin
  select * into d from public.documents where id = p_document_id for update;
  if not found then raise exception 'Documento no encontrado' using errcode = 'P0002'; end if;
  if not public.has_permission(d.company_id, 'documents.review', d.contractor_id) then
    raise exception 'No tienes permiso para revisar documentos de este contratista' using errcode = '42501';
  end if;
  if d.status <> 'in_review' then
    raise exception 'Este documento ya fue revisado o reemplazado' using errcode = '23514';
  end if;
  if p_decision not in ('approved', 'rejected') then
    raise exception 'Decisión no válida' using errcode = '22023';
  end if;
  select * into t from public.document_types where id = d.document_type_id;

  if p_decision = 'rejected' then
    if nullif(trim(coalesce(p_reason, '')), '') is null then
      raise exception 'Indica el motivo del rechazo' using errcode = '22023';
    end if;
    update public.documents set status = 'rejected', rejection_reason = trim(p_reason),
      rejection_note = nullif(trim(coalesce(p_note, '')), ''), reviewed_by = (select auth.uid()), reviewed_at = now()
    where id = d.id;
    insert into public.document_events (company_id, contractor_id, document_id, event_type, actor_user_id, data)
    values (d.company_id, d.contractor_id, d.id, 'rejected', (select auth.uid()),
            jsonb_build_object('reason', trim(p_reason), 'note', nullif(trim(coalesce(p_note, '')), '')));
    return;
  end if;

  -- Aprobación: las fechas confirmadas son las que mandan para las alertas.
  v_issued := coalesce(p_issued_on, d.declared_issued_on);
  v_expires := coalesce(p_expires_on, d.declared_expires_on);
  if v_issued is not null and v_issued > current_date then
    raise exception 'La fecha de emisión no puede ser futura' using errcode = '23514';
  end if;
  if t.requires_dates and v_issued is null then
    raise exception 'Falta la fecha de emisión' using errcode = '23514';
  end if;
  if t.periodicity = 'expiring' and v_expires is null then
    raise exception 'Falta la fecha de vencimiento' using errcode = '23514';
  end if;
  if v_issued is not null and v_expires is not null and v_expires < v_issued then
    raise exception 'La fecha de vencimiento no puede ser anterior a la de emisión' using errcode = '23514';
  end if;
  if t.max_age_days is not null and v_issued is not null then
    if v_issued + t.max_age_days < current_date then
      raise exception 'El documento supera la antigüedad máxima permitida (% días)', t.max_age_days using errcode = '23514';
    end if;
    if t.periodicity <> 'expiring' and v_expires is null then
      v_expires := v_issued + t.max_age_days;
    end if;
  end if;
  if v_expires is not null and v_expires < current_date then
    raise exception 'El documento ya está vencido' using errcode = '23514';
  end if;

  -- El documento aprobado anterior pasa a «reemplazado» (primero, para respetar la unicidad).
  with r as (
    update public.documents x set status = 'replaced'
    where x.contractor_id = d.contractor_id and x.document_type_id = d.document_type_id
      and coalesce(x.worker_id, v_zero) = coalesce(d.worker_id, v_zero) and x.status = 'approved'
    returning x.id
  )
  insert into public.document_events (company_id, contractor_id, document_id, event_type, actor_user_id, data)
  select d.company_id, d.contractor_id, r.id, 'replaced', (select auth.uid()), jsonb_build_object('by', 'approval', 'new_document', d.id) from r;

  update public.documents set status = 'approved', issued_on = v_issued, expires_on = v_expires,
    doc_number = coalesce(nullif(trim(coalesce(p_doc_number, '')), ''), doc_number),
    rejection_reason = null, rejection_note = null, reviewed_by = (select auth.uid()), reviewed_at = now()
  where id = d.id;
  insert into public.document_events (company_id, contractor_id, document_id, event_type, actor_user_id, data)
  values (d.company_id, d.contractor_id, d.id, 'approved', (select auth.uid()),
          jsonb_build_object('issued_on', v_issued, 'expires_on', v_expires));
end $$;

-- ---------- Lista de requisitos de un contratista con su estado ----------
-- Estados: missing, in_review, approved, expiring_soon, expired, rejected, by_contract (se carga por contrato; semana 6).
create or replace function public.contractor_requirements(p_contractor_id uuid)
returns table (
  document_type_id uuid, name text, description text, instructions text, phase text, periodicity text,
  requires_dates boolean, max_age_days integer, owner_kind text, scope text, sort_order integer, is_mandatory boolean,
  worker_id uuid, worker_name text, status text,
  document_id uuid, file_name text, declared_issued_on date, declared_expires_on date,
  issued_on date, expires_on date, rejection_reason text, rejection_note text, uploaded_at timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
declare v_company uuid; v_kind text; v_profile uuid; v_soon integer;
begin
  select c.company_id, c.kind, c.requirement_profile_id into v_company, v_kind, v_profile
  from public.contractors c where c.id = p_contractor_id and c.archived_at is null;
  if v_company is null then raise exception 'Contratista no encontrado' using errcode = 'P0002'; end if;
  if not (public.is_contractor_member(p_contractor_id) or public.can_view_contractor(v_company, p_contractor_id)) then
    raise exception 'No tienes acceso a este contratista' using errcode = '42501';
  end if;
  select coalesce(max(x), 30) into v_soon
  from public.company_settings s cross join lateral unnest(s.alert_days) as x where s.company_id = v_company;
  v_soon := coalesce(v_soon, 30);

  return query
  with reqs as (
    select d.*, i.is_mandatory as mandatory
    from public.requirement_profile_items i join public.document_types d on d.id = i.document_type_id
    where i.requirement_profile_id = v_profile and d.is_active
  ), owners as (
    select r.id as type_id, w.id as w_id, w.full_name as w_name
    from reqs r join public.workers w on w.contractor_id = p_contractor_id and w.status = 'active'
    where r.owner_kind = 'worker' and v_kind = 'company'
    union all
    select r.id, null::uuid, null::text from reqs r where not (r.owner_kind = 'worker' and v_kind = 'company')
  )
  select r.id, r.name, r.description, r.instructions, r.phase, r.periodicity, r.requires_dates, r.max_age_days,
         r.owner_kind, r.scope, r.sort_order, r.mandatory, o.w_id, o.w_name,
         case
           when r.scope = 'contract' then 'by_contract'
           when pend.id is not null then 'in_review'
           when appr.id is not null then
             case when appr.expires_on is not null and appr.expires_on < current_date then 'expired'
                  when appr.expires_on is not null and appr.expires_on <= current_date + v_soon then 'expiring_soon'
                  else 'approved' end
           when rej.id is not null then 'rejected'
           else 'missing'
         end,
         shown.id, shown.file_name, shown.declared_issued_on, shown.declared_expires_on,
         appr.issued_on, appr.expires_on, rej.rejection_reason, rej.rejection_note, shown.created_at
  from reqs r
  join owners o on o.type_id = r.id
  left join lateral (
    select x.* from public.documents x
    where r.scope = 'contractor' and x.contractor_id = p_contractor_id and x.document_type_id = r.id
      and x.worker_id is not distinct from o.w_id and x.status = 'in_review' limit 1
  ) pend on true
  left join lateral (
    select x.* from public.documents x
    where r.scope = 'contractor' and x.contractor_id = p_contractor_id and x.document_type_id = r.id
      and x.worker_id is not distinct from o.w_id and x.status = 'approved' limit 1
  ) appr on true
  left join lateral (
    select x.* from public.documents x
    where r.scope = 'contractor' and x.contractor_id = p_contractor_id and x.document_type_id = r.id
      and x.worker_id is not distinct from o.w_id and x.status = 'rejected'
      and x.created_at > coalesce(appr.created_at, '-infinity'::timestamptz)
    order by x.created_at desc limit 1
  ) rej on true
  left join lateral (select coalesce(pend.id, appr.id, rej.id) as id) pick on true
  left join public.documents shown on shown.id = pick.id
  order by case r.phase when 'contracting' then 1 when 'monthly' then 2 when 'sst' then 3 else 4 end,
           r.sort_order, r.name, o.w_name nulls first;
end $$;

-- ---------- Protecciones de borrado (historial) ----------
-- Un documento del catálogo con archivos cargados, o en un perfil, no se elimina: se desactiva.
create or replace function public.trg_document_types_block_delete()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.companies c where c.id = old.company_id) then
    if exists (select 1 from public.requirement_profile_items i where i.document_type_id = old.id) then
      raise exception 'Este documento está en uno o más perfiles. Quítalo de los perfiles o desactívalo.' using errcode = '23503';
    end if;
    if exists (select 1 from public.documents x where x.document_type_id = old.id) then
      raise exception 'Este documento tiene archivos cargados. Desactívalo en lugar de eliminarlo.' using errcode = '23503';
    end if;
  end if;
  return old;
end $$;

-- Un trabajador con documentos no se elimina: se marca como inactivo.
create or replace function public.trg_workers_block_delete()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.contractors c where c.id = old.contractor_id)
     and exists (select 1 from public.documents x where x.worker_id = old.id) then
    raise exception 'Este trabajador tiene documentos cargados. Márcalo como inactivo en lugar de quitarlo.' using errcode = '23503';
  end if;
  return old;
end $$;

create trigger workers_block_delete before delete on public.workers
  for each row execute function public.trg_workers_block_delete();

revoke execute on function public.trg_documents_before_insert(), public.trg_documents_after_insert(),
  public.trg_workers_block_delete(), public.try_uuid(text) from public, anon, authenticated;
revoke execute on function public.review_document(uuid, text, date, date, text, text, text),
  public.contractor_requirements(uuid) from public, anon, authenticated;
grant execute on function public.review_document(uuid, text, date, date, text, text, text),
  public.contractor_requirements(uuid) to authenticated;
