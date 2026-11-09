-- ContractOK · Semana 2 · Tablas de contratistas, trabajadores, invitaciones y asignaciones

create table public.contractors (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  kind text not null check (kind in ('natural', 'company')),
  display_name text not null check (length(trim(display_name)) > 0),
  legal_name text,
  tax_id text,
  email text not null check (position('@' in email) > 1),
  phone text,
  status text not null default 'invited'
    check (status in ('invited', 'filling', 'in_review', 'observations', 'enabled', 'active', 'closing', 'closed')),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (id, company_id)
);
create unique index contractors_company_email_uidx
  on public.contractors (company_id, lower(email)) where archived_at is null;
create unique index contractors_company_taxid_uidx
  on public.contractors (company_id, lower(tax_id)) where tax_id is not null and archived_at is null;
create index contractors_company_status_idx on public.contractors (company_id, status);

-- Usuarios (de Auth) que acceden al portal en nombre de un contratista.
create table public.contractor_members (
  user_id uuid not null references auth.users (id) on delete cascade,
  contractor_id uuid not null references public.contractors (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, contractor_id)
);
create index contractor_members_contractor_idx on public.contractor_members (contractor_id);

-- Personal de la empresa asignado a un contratista (para responsabilidades con alcance "assigned").
create table public.contractor_assignments (
  contractor_id uuid not null references public.contractors (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (contractor_id, user_id)
);
create index contractor_assignments_user_idx on public.contractor_assignments (user_id);

create table public.workers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  contractor_id uuid not null,
  full_name text not null check (length(trim(full_name)) > 0),
  id_number text not null check (length(trim(id_number)) > 0),
  job_title text,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  unique (contractor_id, id_number),
  foreign key (contractor_id, company_id) references public.contractors (id, company_id) on delete cascade
);
create index workers_contractor_idx on public.workers (contractor_id);

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  contractor_id uuid not null,
  email text not null,
  token_hash text not null unique,
  expires_at timestamptz not null,
  used_at timestamptz,
  revoked_at timestamptz,
  sent_count integer not null default 0,
  last_sent_at timestamptz,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (contractor_id, company_id) references public.contractors (id, company_id) on delete cascade
);
create index invitations_contractor_idx on public.invitations (contractor_id);
