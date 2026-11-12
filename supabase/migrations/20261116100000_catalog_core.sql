-- ContractOK · Semana 3 · Catálogo de documentos y perfiles de requisitos (por empresa)

-- owner_kind: 'contractor' = documento de la empresa o persona contratista;
--             'worker' = documento de quien presta el servicio en sitio: cada trabajador de una empresa
--             contratista o, si el contratista es persona natural, él mismo.
-- scope: 'contractor' = se carga una vez y vale para todos sus contratos; 'contract' = se carga por contrato.
create table public.document_types (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  description text,
  instructions text,
  owner_kind text not null default 'contractor' check (owner_kind in ('contractor', 'worker')),
  scope text not null default 'contractor' check (scope in ('contractor', 'contract')),
  phase text not null check (phase in ('contracting', 'monthly', 'sst', 'closing')),
  periodicity text not null check (periodicity in ('once', 'expiring', 'monthly', 'closing')),
  requires_dates boolean not null default false,
  max_age_days integer check (max_age_days is null or max_age_days between 1 and 3650),
  retention_years integer not null default 10 check (retention_years between 1 and 50),
  alert_category text not null default 'compliance' check (alert_category in ('operational', 'compliance')),
  alert_audience text[] not null default array['contractor', 'reviewer']
    check (alert_audience <@ array['contractor', 'reviewer', 'supervisor', 'admin']::text[]),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, name),
  unique (id, company_id),
  check (periodicity <> 'expiring' or requires_dates),
  check (periodicity <> 'monthly' or phase = 'monthly'),
  check (periodicity <> 'closing' or phase = 'closing'),
  check (owner_kind <> 'worker' or scope = 'contractor')
);
create index document_types_company_idx on public.document_types (company_id, phase, sort_order);

create table public.requirement_profiles (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  description text,
  contractor_kind text not null default 'both' check (contractor_kind in ('natural', 'company', 'both')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, name),
  unique (id, company_id)
);

create table public.requirement_profile_items (
  requirement_profile_id uuid not null,
  document_type_id uuid not null,
  company_id uuid not null,
  is_mandatory boolean not null default true,
  primary key (requirement_profile_id, document_type_id),
  foreign key (requirement_profile_id, company_id)
    references public.requirement_profiles (id, company_id) on delete cascade,
  foreign key (document_type_id, company_id)
    references public.document_types (id, company_id) on delete cascade
);
create index requirement_profile_items_company_idx on public.requirement_profile_items (company_id);

-- Cada contratista puede tener un perfil de requisitos de su empresa.
alter table public.contractors add column requirement_profile_id uuid;
alter table public.contractors add constraint contractors_profile_fk
  foreign key (requirement_profile_id, company_id)
  references public.requirement_profiles (id, company_id) on delete set null (requirement_profile_id);

create trigger document_types_set_updated_at before update on public.document_types
  for each row execute function public.set_updated_at();
create trigger requirement_profiles_set_updated_at before update on public.requirement_profiles
  for each row execute function public.set_updated_at();

-- El perfil asignado debe servir para el tipo de contratista (persona natural / empresa).
create or replace function public.trg_contractors_profile_kind()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.requirement_profile_id is not null and not exists (
    select 1 from public.requirement_profiles p
    where p.id = new.requirement_profile_id and p.company_id = new.company_id
      and p.contractor_kind in ('both', new.kind)
  ) then
    raise exception 'El perfil de requisitos no aplica a este tipo de contratista' using errcode = '23514';
  end if;
  return new;
end $$;

create trigger contractors_profile_kind before insert or update of requirement_profile_id, kind on public.contractors
  for each row execute function public.trg_contractors_profile_kind();

-- Protección: no se borra un documento que está en un perfil, ni un perfil que usan contratistas
-- (se desactivan). Las llaves foráneas borran en cascada solo para poder eliminar una empresa completa;
-- estos disparadores se desactivan únicamente cuando la empresa ya no existe.
create or replace function public.trg_document_types_block_delete()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.companies c where c.id = old.company_id)
     and exists (select 1 from public.requirement_profile_items i where i.document_type_id = old.id) then
    raise exception 'Este documento está en uno o más perfiles. Quítalo de los perfiles o desactívalo.' using errcode = '23503';
  end if;
  return old;
end $$;

create trigger document_types_block_delete before delete on public.document_types
  for each row execute function public.trg_document_types_block_delete();

create or replace function public.trg_requirement_profiles_block_delete()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.companies c where c.id = old.company_id)
     and exists (select 1 from public.contractors k where k.requirement_profile_id = old.id) then
    raise exception 'Este perfil está asignado a contratistas. Desactívalo en lugar de eliminarlo.' using errcode = '23503';
  end if;
  return old;
end $$;

create trigger requirement_profiles_block_delete before delete on public.requirement_profiles
  for each row execute function public.trg_requirement_profiles_block_delete();

revoke execute on function public.trg_contractors_profile_kind(), public.trg_document_types_block_delete(),
  public.trg_requirement_profiles_block_delete() from public, anon, authenticated;
