-- ContractOK · Semana 4 · Parte 1 · Documentos cargados y su historial
-- Cada fila es un archivo cargado para un requisito de un contratista (o de uno de sus trabajadores).
-- Estados: in_review (pendiente de revisión), approved (válido), rejected, replaced (reemplazado por otro).

create function public.try_uuid(p text)
returns uuid language plpgsql immutable set search_path = '' as $$
begin
  return p::uuid;
exception when others then
  return null;
end $$;

-- Para que un documento pueda apuntar a un trabajador de ESE contratista.
alter table public.workers add constraint workers_id_contractor_uk unique (id, contractor_id);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  contractor_id uuid not null,
  document_type_id uuid not null,
  worker_id uuid,
  version integer not null default 1,
  status text not null default 'in_review' check (status in ('in_review', 'approved', 'rejected', 'replaced')),
  file_path text not null,
  file_name text not null check (length(trim(file_name)) > 0),
  mime_type text not null check (mime_type in ('application/pdf', 'image/jpeg', 'image/png')),
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 10485760),
  doc_number text,
  declared_issued_on date,
  declared_expires_on date,
  issued_on date,
  expires_on date,
  rejection_reason text,
  rejection_note text,
  reviewed_by uuid references auth.users (id) on delete set null,
  reviewed_at timestamptz,
  uploaded_by uuid references auth.users (id) on delete set null,
  uploaded_via text not null default 'contractor' check (uploaded_via in ('contractor', 'assisted')),
  extracted_data jsonb,
  ai_confidence numeric check (ai_confidence is null or ai_confidence between 0 and 1),
  created_at timestamptz not null default now(),
  foreign key (contractor_id, company_id) references public.contractors (id, company_id) on delete cascade,
  foreign key (document_type_id, company_id) references public.document_types (id, company_id) on delete cascade,
  foreign key (worker_id, contractor_id) references public.workers (id, contractor_id) on delete cascade,
  -- Los archivos viven en company_id/contractor_id/archivo
  check (starts_with(file_path, company_id::text || '/' || contractor_id::text || '/'))
);

-- Por cada requisito (contratista + tipo + trabajador) solo puede haber 1 documento pendiente y 1 aprobado.
create unique index documents_one_pending_uidx on public.documents
  (contractor_id, document_type_id, coalesce(worker_id, '00000000-0000-0000-0000-000000000000'::uuid)) where status = 'in_review';
create unique index documents_one_approved_uidx on public.documents
  (contractor_id, document_type_id, coalesce(worker_id, '00000000-0000-0000-0000-000000000000'::uuid)) where status = 'approved';
create index documents_contractor_idx on public.documents (contractor_id, document_type_id);
create index documents_company_status_idx on public.documents (company_id, status);

-- Historial: solo se agregan filas.
create table public.document_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  contractor_id uuid not null,
  document_id uuid not null references public.documents (id) on delete cascade,
  event_type text not null check (event_type in ('uploaded', 'approved', 'rejected', 'replaced')),
  actor_user_id uuid references auth.users (id) on delete set null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  foreign key (contractor_id, company_id) references public.contractors (id, company_id) on delete cascade
);
create index document_events_document_idx on public.document_events (document_id, created_at);
create index document_events_contractor_idx on public.document_events (contractor_id, created_at);
