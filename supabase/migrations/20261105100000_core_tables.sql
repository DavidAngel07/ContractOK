-- ContractOK · Semana 1 · Tablas base
-- Empresas, ajustes, perfiles, catálogo de permisos, roles y membresías.

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  nit text,
  address text,
  city text,
  country text not null default 'CO',
  logo_path text,
  contact_email text,
  contact_phone text,
  timezone text not null default 'America/Bogota',
  setup_status text not null default 'not_started'
    check (setup_status in ('not_started', 'in_progress', 'completed')),
  setup_step integer not null default 0 check (setup_step >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.company_settings (
  company_id uuid primary key references public.companies (id) on delete cascade,
  alert_days integer[] not null default '{30,15,7,0}' check (cardinality(alert_days) > 0),
  monthly_period_open_day integer not null default 1 check (monthly_period_open_day between 1 and 28),
  invitation_valid_days integer not null default 7 check (invitation_valid_days between 1 and 60),
  reminder_after_days integer not null default 3 check (reminder_after_days between 1 and 30),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  job_title text,
  phone text,
  avatar_path text,
  ui_preferences jsonb not null default '{}'::jsonb check (jsonb_typeof(ui_preferences) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Catálogo fijo de responsabilidades. Lo define el sistema, no los usuarios.
create table public.permissions (
  key text primary key,
  description text not null
);

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  description text,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  unique (company_id, name),
  unique (id, company_id)
);
create index roles_company_id_idx on public.roles (company_id);

create table public.role_permissions (
  role_id uuid not null references public.roles (id) on delete cascade,
  permission_key text not null references public.permissions (key) on delete restrict,
  scope text not null default 'all' check (scope in ('all', 'assigned')),
  primary key (role_id, permission_key)
);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role_id uuid not null,
  status text not null default 'invited' check (status in ('invited', 'active', 'disabled')),
  invited_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (company_id, user_id),
  -- El rol debe pertenecer a la misma empresa de la membresía.
  foreign key (role_id, company_id) references public.roles (id, company_id) on delete restrict
);
create index memberships_user_id_idx on public.memberships (user_id);
create index memberships_company_id_idx on public.memberships (company_id);
