-- ContractOK · Semana 4 · Parte 1 · Seguridad por filas y almacenamiento privado de archivos

alter table public.documents enable row level security;
alter table public.document_events enable row level security;

-- Lectura: quien puede ver al contratista (según sus responsabilidades) y el propio contratista.
create policy documents_select on public.documents for select to authenticated
  using (public.can_view_contractor(company_id, contractor_id) or public.is_contractor_member(contractor_id));
-- Subida: el contratista por sí mismo, o el personal autorizado en su nombre (carga asistida).
create policy documents_insert on public.documents for insert to authenticated
  with check (
    (uploaded_via = 'contractor' and public.is_contractor_member(contractor_id))
    or (uploaded_via = 'assisted' and public.has_permission(company_id, 'documents.upload_on_behalf', contractor_id))
  );
-- No hay políticas de UPDATE ni DELETE: los cambios de estado se hacen con review_document.

create policy document_events_select on public.document_events for select to authenticated
  using (public.can_view_contractor(company_id, contractor_id) or public.is_contractor_member(contractor_id));

revoke all on public.documents, public.document_events from anon;
revoke all on public.documents, public.document_events from authenticated;
grant select on public.documents to authenticated;
-- Solo estas columnas las informa quien sube; el resto (estado, fechas confirmadas, revisión) las fija la base de datos.
grant insert (company_id, contractor_id, document_type_id, worker_id, file_path, file_name, mime_type, size_bytes,
              doc_number, declared_issued_on, declared_expires_on, uploaded_via)
  on public.documents to authenticated;
grant select on public.document_events to authenticated;
grant all on public.documents, public.document_events to service_role;

-- ---------- Archivos ----------
-- Ruta: <company_id>/<contractor_id>/<archivo>. Quién puede subir o leer se decide con estas reglas.
create or replace function public.can_access_document_path(p_name text, p_mode text)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare parts text[]; v_company uuid; v_contractor uuid;
begin
  parts := string_to_array(coalesce(p_name, ''), '/');
  if coalesce(array_length(parts, 1), 0) < 3 then return false; end if;
  v_company := public.try_uuid(parts[1]);
  v_contractor := public.try_uuid(parts[2]);
  if v_company is null or v_contractor is null then return false; end if;
  if public.contractor_company_id(v_contractor) is distinct from v_company then return false; end if;
  if p_mode = 'upload' then
    return public.is_contractor_member(v_contractor)
        or public.has_permission(v_company, 'documents.upload_on_behalf', v_contractor);
  elsif p_mode = 'read' then
    return public.is_contractor_member(v_contractor) or public.can_view_contractor(v_company, v_contractor);
  end if;
  return false;
end $$;

revoke execute on function public.can_access_document_path(text, text) from public, anon, authenticated;
grant execute on function public.can_access_document_path(text, text) to authenticated;

-- Bucket privado, hasta 10 MB y solo PDF, JPG o PNG.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documents', 'documents', false, 10485760, array['application/pdf', 'image/jpeg', 'image/png'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy documents_files_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'documents' and public.can_access_document_path(name, 'upload'));
create policy documents_files_select on storage.objects for select to authenticated
  using (bucket_id = 'documents' and public.can_access_document_path(name, 'read'));
-- Sin políticas de UPDATE ni DELETE: los archivos no se modifican ni se borran desde la aplicación.
