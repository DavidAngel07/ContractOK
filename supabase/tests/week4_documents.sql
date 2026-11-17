-- ContractOK · Semana 4 · Parte 1 · Pruebas de documentos, revisión y estado de requisitos
-- Pega TODO este archivo en el Editor SQL de Supabase (contractok-dev) y ejecútalo.
-- Todo ocurre en una transacción que termina con ROLLBACK (no deja datos; también se deshacen las funciones auxiliares tt_*).
-- Si algo falla verás un error que empieza con "FALLÓ". Si todo pasa, el último resultado dice OK.

begin;

-- ===== Funciones auxiliares de la prueba (se deshacen al final) =====
create function public.tt_act(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

create function public.tt_ins(p_company uuid, p_contractor uuid, p_type uuid, p_worker uuid, p_issued date, p_expires date,
  p_via text default 'contractor', p_mime text default 'application/pdf', p_size bigint default 1000, p_path text default null)
returns text language plpgsql as $$
begin
  insert into public.documents (company_id, contractor_id, document_type_id, worker_id, file_path, file_name, mime_type, size_bytes,
                                declared_issued_on, declared_expires_on, uploaded_via)
  values (p_company, p_contractor, p_type, p_worker,
          coalesce(p_path, p_company::text || '/' || p_contractor::text || '/' || gen_random_uuid()::text || '.pdf'),
          'archivo.pdf', p_mime, p_size, p_issued, p_expires, p_via);
  return 'OK';
exception when others then return sqlstate || ': ' || sqlerrm;
end $$;

create function public.tt_rev(p_doc uuid, p_decision text, p_issued date default null, p_expires date default null,
  p_number text default null, p_reason text default null, p_note text default null)
returns text language plpgsql as $$
begin
  perform public.review_document(p_doc, p_decision, p_issued, p_expires, p_number, p_reason, p_note);
  return 'OK';
exception when others then return sqlstate || ': ' || sqlerrm;
end $$;

create function public.tt_doc(p_contractor uuid, p_type uuid, p_worker uuid, p_status text) returns uuid language sql as $$
  select id from public.documents
  where contractor_id = p_contractor and document_type_id = p_type and worker_id is not distinct from p_worker and status = p_status
  order by version desc limit 1
$$;

create function public.tt_type(p_company uuid, p_name text) returns uuid language sql as $$
  select id from public.document_types where company_id = p_company and name = p_name
$$;

-- ===== Preparación =====
do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000aaaa';
  b constant uuid := '00000000-0000-0000-0000-00000000bbbb';
  n uuid := '00000000-0000-0000-0000-00000000a001';
  k uuid := '00000000-0000-0000-0000-00000000a002';
  np uuid := '00000000-0000-0000-0000-00000000a003';
  bk uuid := '00000000-0000-0000-0000-00000000b001';
begin
  insert into auth.users (id, email) values
    ('00000000-0000-0000-0000-000000000a01', 'admin.a@test.local'),
    ('00000000-0000-0000-0000-000000000a02', 'revisor.a@test.local'),
    ('00000000-0000-0000-0000-000000000a03', 'consulta.a@test.local'),
    ('00000000-0000-0000-0000-000000000b01', 'admin.b@test.local'),
    ('00000000-0000-0000-0000-000000000c01', 'natural@contratista.com'),
    ('00000000-0000-0000-0000-000000000c02', 'empresa@contratista.com'),
    ('00000000-0000-0000-0000-000000000c03', 'otra@contratista.com');
  insert into public.companies (id, name) values (a, 'Empresa A'), (b, 'Empresa B');
  perform public.add_member(a, '00000000-0000-0000-0000-000000000a01', 'Administrador');
  perform public.add_member(a, '00000000-0000-0000-0000-000000000a02', 'Revisor SST');
  perform public.add_member(a, '00000000-0000-0000-0000-000000000a03', 'Consulta');
  perform public.add_member(b, '00000000-0000-0000-0000-000000000b01', 'Administrador');

  insert into public.contractors (id, company_id, kind, display_name, email, status, requirement_profile_id) values
    (n, a, 'natural', 'Carlos Natural', 'natural@contratista.com', 'filling',
      (select id from public.requirement_profiles where company_id = a and name = 'Persona natural · operativo en sitio')),
    (k, a, 'company', 'Empresa K', 'empresa@contratista.com', 'filling',
      (select id from public.requirement_profiles where company_id = a and name = 'Empresa contratista · personal en sitio')),
    (np, a, 'natural', 'Sin Perfil', 'sinperfil@contratista.com', 'filling', null),
    (bk, b, 'company', 'Contratista B', 'otra@contratista.com', 'filling',
      (select id from public.requirement_profiles where company_id = b and name = 'Empresa contratista · personal en sitio'));
  insert into public.contractor_members (user_id, contractor_id) values
    ('00000000-0000-0000-0000-000000000c01', n), ('00000000-0000-0000-0000-000000000c02', k), ('00000000-0000-0000-0000-000000000c03', bk);
  insert into public.workers (id, company_id, contractor_id, full_name, id_number, status) values
    ('00000000-0000-0000-0000-0000000000f1', a, k, 'Pedro', '1001', 'active'),
    ('00000000-0000-0000-0000-0000000000f2', a, k, 'Ana', '1002', 'active'),
    ('00000000-0000-0000-0000-0000000000f3', a, k, 'Luis', '1003', 'inactive'),
    ('00000000-0000-0000-0000-0000000000f9', b, bk, 'Zed', '9001', 'active');
end $$;

-- ===== Grupo 1: contratista persona natural sube sus documentos =====
do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000aaaa';
  b constant uuid := '00000000-0000-0000-0000-00000000bbbb';
  n constant uuid := '00000000-0000-0000-0000-00000000a001';
  k constant uuid := '00000000-0000-0000-0000-00000000a002';
  np constant uuid := '00000000-0000-0000-0000-00000000a003';
  t_rut uuid := public.tt_type(a, 'RUT actualizado');
  t_exam uuid := public.tt_type(a, 'Examen médico ocupacional');
  t_poliza uuid := public.tt_type(a, 'Póliza de responsabilidad civil');
  t_contrato uuid := public.tt_type(a, 'Contrato firmado');
  t_idon uuid := public.tt_type(a, 'Certificados de idoneidad');
  r text; d record; cnt integer; failed boolean;
begin
  perform public.tt_act('00000000-0000-0000-0000-000000000c01');

  if public.tt_ins(a, n, t_rut, null, null, null) <> 'OK' then raise exception 'FALLÓ [1.1]: no pudo subir un documento válido'; end if;
  select * into d from public.documents where contractor_id = n and document_type_id = t_rut;
  if d.status <> 'in_review' or d.version <> 1 or d.uploaded_by <> '00000000-0000-0000-0000-000000000c01'
     or d.issued_on is not null or d.reviewed_by is not null then
    raise exception 'FALLÓ [1.2]: el documento debe quedar pendiente, versión 1 y subido por quien lo cargó: %', d;
  end if;

  -- No puede decidir su propio estado ni sus fechas confirmadas
  failed := false;
  begin
    insert into public.documents (company_id, contractor_id, document_type_id, file_path, file_name, mime_type, size_bytes, status, issued_on)
    values (a, n, t_idon, a::text || '/' || n::text || '/x.pdf', 'x.pdf', 'application/pdf', 100, 'approved', current_date);
  exception when insufficient_privilege then failed := true; end;
  if not failed then raise exception 'FALLÓ [1.3]: el contratista pudo fijar el estado o las fechas confirmadas'; end if;

  r := public.tt_ins(a, n, t_poliza, null, current_date - 10, current_date + 300); -- con fechas válidas: solo el perfil puede rechazarlo
  if left(r, 5) <> '23514' or r not like '%perfil%' then raise exception 'FALLÓ [1.4]: aceptó un documento que no está en su perfil: %', r; end if;
  r := public.tt_ins(a, n, t_contrato, null, null, null);
  if left(r, 5) <> '23514' or r not like '%por contrato%' then raise exception 'FALLÓ [1.5]: aceptó un documento que se carga por contrato: %', r; end if;

  -- Fechas
  r := public.tt_ins(a, n, t_exam, null, null, null);
  if left(r, 5) <> '23514' then raise exception 'FALLÓ [1.6]: aceptó un examen sin fechas: %', r; end if;
  r := public.tt_ins(a, n, t_exam, null, current_date - 10, null);
  if left(r, 5) <> '23514' then raise exception 'FALLÓ [1.7]: aceptó un documento con vencimiento sin fecha de vencimiento: %', r; end if;
  r := public.tt_ins(a, n, t_exam, null, current_date + 5, current_date + 400);
  if left(r, 5) <> '23514' then raise exception 'FALLÓ [1.8]: aceptó una fecha de emisión futura: %', r; end if;
  r := public.tt_ins(a, n, t_exam, null, current_date - 10, current_date - 20);
  if left(r, 5) <> '23514' then raise exception 'FALLÓ [1.9]: aceptó vencimiento anterior a la emisión: %', r; end if;
  if public.tt_ins(a, n, t_exam, null, current_date - 10, current_date + 355) <> 'OK' then raise exception 'FALLÓ [1.10]: no aceptó un examen con fechas válidas'; end if;

  r := public.tt_ins(a, n, t_exam, '00000000-0000-0000-0000-0000000000f1', current_date - 10, current_date + 355);
  if r = 'OK' then raise exception 'FALLÓ [1.11]: un contratista persona natural subió un documento de un trabajador ajeno'; end if;

  -- Reemplazo del pendiente
  if public.tt_ins(a, n, t_rut, null, null, null) <> 'OK' then raise exception 'FALLÓ [1.12]: no pudo volver a subir el documento'; end if;
  select count(*) filter (where status = 'in_review'), count(*) filter (where status = 'replaced'), max(version)
    into d from public.documents where contractor_id = n and document_type_id = t_rut;
  if d.count <> 1 then raise exception 'FALLÓ [1.13]: debe quedar un solo pendiente'; end if;

  -- Archivo con formato o tamaño no permitido
  r := public.tt_ins(a, n, t_idon, null, null, null, 'contractor', 'text/html');
  if left(r, 5) <> '23514' then raise exception 'FALLÓ [1.14]: aceptó un tipo de archivo no permitido: %', r; end if;
  r := public.tt_ins(a, n, t_idon, null, null, null, 'contractor', 'application/pdf', 11000000);
  if left(r, 5) <> '23514' then raise exception 'FALLÓ [1.15]: aceptó un archivo de más de 10 MB: %', r; end if;
  r := public.tt_ins(a, n, t_idon, null, null, null, 'contractor', 'application/pdf', 1000, b::text || '/' || n::text || '/malo.pdf');
  if left(r, 5) <> '23514' then raise exception 'FALLÓ [1.16]: aceptó una ruta de archivo de otra empresa: %', r; end if;

  -- No puede hacerse pasar por personal ni subir a otro contratista
  r := public.tt_ins(a, n, t_idon, null, null, null, 'assisted');
  if r = 'OK' then raise exception 'FALLÓ [1.17]: el contratista subió como carga asistida'; end if;
  r := public.tt_ins(a, k, t_rut, null, null, null);
  if r = 'OK' then raise exception 'FALLÓ [1.18]: subió un documento a otro contratista'; end if;
  reset role;

  -- Documento desactivado y contratista sin perfil
  update public.document_types set is_active = false where id = t_idon;
  perform public.tt_act('00000000-0000-0000-0000-000000000c01');
  r := public.tt_ins(a, n, t_idon, null, null, null);
  if left(r, 5) <> '23514' then raise exception 'FALLÓ [1.19]: aceptó un documento desactivado: %', r; end if;
  reset role;
  update public.document_types set is_active = true where id = t_idon;
  perform public.tt_act('00000000-0000-0000-0000-000000000a02');
  r := public.tt_ins(a, np, t_rut, null, null, null, 'assisted');
  if left(r, 5) <> '23514' or r not like '%perfil%' then raise exception 'FALLÓ [1.20]: aceptó un documento para un contratista sin perfil: %', r; end if;
  reset role;
end $$;

-- ===== Grupo 2: empresa contratista con trabajadores =====
do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000aaaa';
  n constant uuid := '00000000-0000-0000-0000-00000000a001';
  k constant uuid := '00000000-0000-0000-0000-00000000a002';
  w1 constant uuid := '00000000-0000-0000-0000-0000000000f1';
  w2 constant uuid := '00000000-0000-0000-0000-0000000000f2';
  w3 constant uuid := '00000000-0000-0000-0000-0000000000f3';
  w9 constant uuid := '00000000-0000-0000-0000-0000000000f9';
  t_exam uuid := public.tt_type(a, 'Examen médico ocupacional');
  t_rut uuid := public.tt_type(a, 'RUT actualizado');
  r text; cnt integer;
begin
  perform public.tt_act('00000000-0000-0000-0000-000000000c02');
  r := public.tt_ins(a, k, t_exam, null, current_date - 10, current_date + 300);
  if left(r, 5) <> '23514' then raise exception 'FALLÓ [2.1]: aceptó un documento de trabajador sin indicar el trabajador: %', r; end if;
  r := public.tt_ins(a, k, t_exam, w3, current_date - 10, current_date + 300);
  if left(r, 5) <> '23514' then raise exception 'FALLÓ [2.2]: aceptó un trabajador inactivo: %', r; end if;
  r := public.tt_ins(a, k, t_exam, w9, current_date - 10, current_date + 300);
  if r = 'OK' then raise exception 'FALLÓ [2.3]: aceptó un trabajador de otro contratista'; end if;
  if public.tt_ins(a, k, t_exam, w1, current_date - 10, current_date + 300) <> 'OK' then raise exception 'FALLÓ [2.4]: no aceptó el examen de un trabajador'; end if;
  if public.tt_ins(a, k, t_exam, w2, current_date - 10, current_date + 300) <> 'OK' then raise exception 'FALLÓ [2.5]: no aceptó el examen del segundo trabajador'; end if;
  r := public.tt_ins(a, k, t_rut, w1, null, null);
  if left(r, 5) <> '23514' then raise exception 'FALLÓ [2.6]: aceptó un documento de la empresa asociado a un trabajador: %', r; end if;

  -- Cada trabajador tiene su propio documento pendiente (no se reemplazan entre sí)
  select count(*) into cnt from public.documents where contractor_id = k and document_type_id = t_exam and status = 'in_review';
  if cnt <> 2 then raise exception 'FALLÓ [2.7]: deben existir 2 pendientes (uno por trabajador) y hay %', cnt; end if;
  -- Solo ve lo suyo
  select count(*) into cnt from public.documents where contractor_id <> k;
  if cnt <> 0 then raise exception 'FALLÓ [2.8]: el contratista ve documentos de otros'; end if;
  reset role;
  -- Otro contratista no ve ni toca los documentos de K ni de N
  perform public.tt_act('00000000-0000-0000-0000-000000000c03');
  select count(*) into cnt from public.documents where contractor_id in (k, n);
  if cnt <> 0 then raise exception 'FALLÓ [2.9]: otro contratista ve documentos ajenos'; end if;
  reset role;
end $$;

-- ===== Grupo 3: carga asistida por el personal =====
do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000aaaa';
  n constant uuid := '00000000-0000-0000-0000-00000000a001';
  t_banco uuid := public.tt_type(a, 'Certificación bancaria');
  r text; d record; cnt integer;
begin
  perform public.tt_act('00000000-0000-0000-0000-000000000a02');
  if public.tt_ins(a, n, t_banco, null, null, null, 'assisted') <> 'OK' then raise exception 'FALLÓ [3.1]: el revisor no pudo cargar en nombre del contratista'; end if;
  select uploaded_via, uploaded_by into d from public.documents where contractor_id = n and document_type_id = t_banco;
  if d.uploaded_via <> 'assisted' or d.uploaded_by <> '00000000-0000-0000-0000-000000000a02' then raise exception 'FALLÓ [3.2]: la carga asistida debe quedar registrada'; end if;
  r := public.tt_ins(a, n, public.tt_type(a, 'Documento de identidad'), null, null, null, 'contractor');
  if r = 'OK' then raise exception 'FALLÓ [3.3]: el personal subió como si fuera el contratista'; end if;
  reset role;

  perform public.tt_act('00000000-0000-0000-0000-000000000a03');
  r := public.tt_ins(a, n, public.tt_type(a, 'Documento de identidad'), null, null, null, 'assisted');
  if r = 'OK' then raise exception 'FALLÓ [3.4]: un rol de solo lectura pudo cargar documentos'; end if;
  select count(*) into cnt from public.documents where contractor_id = n;
  if cnt = 0 then raise exception 'FALLÓ [3.5]: un rol de solo lectura debe poder ver los documentos de su empresa'; end if;
  reset role;

  perform public.tt_act('00000000-0000-0000-0000-000000000b01');
  select count(*) into cnt from public.documents;
  if cnt <> 0 then raise exception 'FALLÓ [3.6]: el administrador de otra empresa ve documentos'; end if;
  r := public.tt_ins(a, n, t_banco, null, null, null, 'assisted');
  if r = 'OK' then raise exception 'FALLÓ [3.7]: el personal de otra empresa pudo cargar documentos'; end if;
  reset role;
end $$;

-- ===== Grupo 4: revisión =====
do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000aaaa';
  n constant uuid := '00000000-0000-0000-0000-00000000a001';
  k constant uuid := '00000000-0000-0000-0000-00000000a002';
  w1 constant uuid := '00000000-0000-0000-0000-0000000000f1';
  t_rut uuid := public.tt_type(a, 'RUT actualizado');
  t_exam uuid := public.tt_type(a, 'Examen médico ocupacional');
  t_camara uuid := public.tt_type(a, 'Certificado de Cámara de Comercio');
  t_alturas uuid := public.tt_type(a, 'Curso de trabajo en alturas');
  doc uuid; r text; d record; cnt integer;
begin
  doc := (select id from public.documents where contractor_id = n and document_type_id = t_rut and status = 'in_review');

  perform public.tt_act('00000000-0000-0000-0000-000000000a03');
  r := public.tt_rev(doc, 'approved');
  if left(r, 5) <> '42501' then raise exception 'FALLÓ [4.1]: un rol sin permiso pudo revisar: %', r; end if;
  reset role;

  perform public.tt_act('00000000-0000-0000-0000-000000000b01');
  r := public.tt_rev(doc, 'approved');
  if left(r, 5) <> '42501' and left(r, 5) <> 'P0002' then raise exception 'FALLÓ [4.2]: el personal de otra empresa pudo revisar: %', r; end if;
  reset role;

  perform public.tt_act('00000000-0000-0000-0000-000000000a02');
  r := public.tt_rev(doc, 'rejected');
  if left(r, 5) <> '22023' then raise exception 'FALLÓ [4.3]: rechazó sin indicar el motivo: %', r; end if;
  r := public.tt_rev(doc, 'maybe');
  if left(r, 5) <> '22023' then raise exception 'FALLÓ [4.4]: aceptó una decisión inválida: %', r; end if;
  if public.tt_rev(doc, 'rejected', null, null, null, 'Documento ilegible', 'Sube una foto más clara') <> 'OK' then raise exception 'FALLÓ [4.5]: no pudo rechazar con motivo'; end if;
  select status, rejection_reason, rejection_note, reviewed_by into d from public.documents where id = doc;
  if d.status <> 'rejected' or d.rejection_reason <> 'Documento ilegible' or d.rejection_note <> 'Sube una foto más clara' or d.reviewed_by is null then
    raise exception 'FALLÓ [4.6]: el rechazo no quedó registrado: %', d;
  end if;
  r := public.tt_rev(doc, 'approved');
  if left(r, 5) <> '23514' then raise exception 'FALLÓ [4.7]: revisó dos veces el mismo documento: %', r; end if;
  reset role;

  -- El contratista ve el motivo y vuelve a subir
  perform public.tt_act('00000000-0000-0000-0000-000000000c01');
  select rejection_reason into r from public.documents where id = doc;
  if r <> 'Documento ilegible' then raise exception 'FALLÓ [4.8]: el contratista no ve el motivo del rechazo'; end if;
  if public.tt_ins(a, n, t_rut, null, null, null) <> 'OK' then raise exception 'FALLÓ [4.9]: no pudo volver a subir'; end if;
  reset role;

  perform public.tt_act('00000000-0000-0000-0000-000000000a02');
  doc := (select id from public.documents where contractor_id = n and document_type_id = t_rut and status = 'in_review');
  if public.tt_rev(doc, 'approved', null, null, 'NIT 900.123') <> 'OK' then raise exception 'FALLÓ [4.10]: no pudo aprobar'; end if;
  select status, issued_on, expires_on, doc_number, reviewed_by into d from public.documents where id = doc;
  if d.status <> 'approved' or d.doc_number <> 'NIT 900.123' or d.expires_on is not null then raise exception 'FALLÓ [4.11]: aprobación incorrecta: %', d; end if;

  -- Aprobar con fechas: la fecha confirmada por el revisor manda sobre la declarada
  doc := (select id from public.documents where contractor_id = n and document_type_id = t_exam and status = 'in_review');
  if public.tt_rev(doc, 'approved', current_date - 5, current_date + 200) <> 'OK' then raise exception 'FALLÓ [4.12]: no pudo aprobar con fechas corregidas'; end if;
  select issued_on, expires_on into d from public.documents where id = doc;
  if d.issued_on <> current_date - 5 or d.expires_on <> current_date + 200 then raise exception 'FALLÓ [4.13]: se guardaron fechas distintas a las confirmadas: %', d; end if;

  -- Un documento ya vencido no se aprueba
  reset role;
  perform public.tt_act('00000000-0000-0000-0000-000000000c02');
  perform public.tt_ins(a, k, t_alturas, w1, current_date - 400, current_date - 5);
  reset role;
  perform public.tt_act('00000000-0000-0000-0000-000000000a02');
  doc := (select id from public.documents where contractor_id = k and document_type_id = t_alturas and status = 'in_review');
  r := public.tt_rev(doc, 'approved');
  if left(r, 5) <> '23514' or r not like '%vencido%' then raise exception 'FALLÓ [4.14]: aprobó un documento ya vencido: %', r; end if;
  perform public.tt_rev(doc, 'rejected', null, null, null, 'Documento vencido');

  -- Antigüedad máxima: Cámara de Comercio (90 días)
  reset role;
  perform public.tt_act('00000000-0000-0000-0000-000000000c02');
  perform public.tt_ins(a, k, t_camara, null, current_date - 100, null);
  reset role;
  perform public.tt_act('00000000-0000-0000-0000-000000000a02');
  doc := (select id from public.documents where contractor_id = k and document_type_id = t_camara and status = 'in_review');
  r := public.tt_rev(doc, 'approved');
  if left(r, 5) <> '23514' or r not like '%antigüedad%' then raise exception 'FALLÓ [4.15]: aprobó un documento que supera la antigüedad máxima: %', r; end if;
  perform public.tt_rev(doc, 'rejected', null, null, null, 'Demasiado antiguo');
  reset role;
  perform public.tt_act('00000000-0000-0000-0000-000000000c02');
  perform public.tt_ins(a, k, t_camara, null, current_date - 10, null);
  reset role;
  perform public.tt_act('00000000-0000-0000-0000-000000000a02');
  doc := (select id from public.documents where contractor_id = k and document_type_id = t_camara and status = 'in_review');
  if public.tt_rev(doc, 'approved') <> 'OK' then raise exception 'FALLÓ [4.16]: no aprobó la Cámara de Comercio vigente'; end if;
  select expires_on into d from public.documents where id = doc;
  if d.expires_on <> current_date - 10 + 90 then raise exception 'FALLÓ [4.17]: el vencimiento debe ser emisión + 90 días y es %', d.expires_on; end if;
  reset role;

  -- Aprobar una renovación reemplaza al documento aprobado anterior
  perform public.tt_act('00000000-0000-0000-0000-000000000c01');
  perform public.tt_ins(a, n, t_rut, null, null, null);
  reset role;
  perform public.tt_act('00000000-0000-0000-0000-000000000a02');
  doc := (select id from public.documents where contractor_id = n and document_type_id = t_rut and status = 'in_review');
  if public.tt_rev(doc, 'approved') <> 'OK' then raise exception 'FALLÓ [4.18]: no aprobó la renovación'; end if;
  select count(*) into cnt from public.documents where contractor_id = n and document_type_id = t_rut and status = 'approved';
  if cnt <> 1 then raise exception 'FALLÓ [4.19]: debe haber un solo documento aprobado y hay %', cnt; end if;
  select count(*) into cnt from public.document_events where contractor_id = n and event_type = 'replaced';
  if cnt < 2 then raise exception 'FALLÓ [4.20]: debe haber eventos de reemplazo y hay %', cnt; end if;
  select count(*) into cnt from public.document_events where contractor_id = n and event_type = 'uploaded';
  if cnt < 5 then raise exception 'FALLÓ [4.21]: faltan eventos de carga (%)', cnt; end if;
  select count(*) into cnt from public.document_events where contractor_id = n and event_type = 'rejected';
  if cnt <> 1 then raise exception 'FALLÓ [4.22]: debe haber 1 evento de rechazo y hay %', cnt; end if;
  reset role;
end $$;

-- ===== Grupo 5: lo que nadie puede cambiar a mano =====
do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000aaaa';
  n constant uuid := '00000000-0000-0000-0000-00000000a001';
  u text; cnt integer; failed boolean;
begin
  foreach u in array array['00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-000000000a02', '00000000-0000-0000-0000-000000000a01'] loop
    perform public.tt_act(u::uuid);
    failed := false;
    begin update public.documents set status = 'approved' where contractor_id = n; exception when insufficient_privilege then failed := true; end;
    if not failed then raise exception 'FALLÓ [5.1]: % pudo modificar documentos directamente', u; end if;
    failed := false;
    begin delete from public.documents where contractor_id = n; exception when insufficient_privilege then failed := true; end;
    if not failed then raise exception 'FALLÓ [5.2]: % pudo borrar documentos', u; end if;
    failed := false;
    begin insert into public.document_events (company_id, contractor_id, document_id, event_type) select company_id, contractor_id, id, 'approved' from public.documents limit 1;
    exception when insufficient_privilege then failed := true; end;
    if not failed then raise exception 'FALLÓ [5.3]: % pudo escribir el historial', u; end if;
    failed := false;
    begin update public.document_events set event_type = 'rejected'; exception when insufficient_privilege then failed := true; end;
    if not failed then raise exception 'FALLÓ [5.4]: % pudo modificar el historial', u; end if;
    reset role;
  end loop;

  perform public.tt_act('00000000-0000-0000-0000-000000000c01');
  select count(*) into cnt from public.document_events where contractor_id = n;
  if cnt = 0 then raise exception 'FALLÓ [5.5]: el contratista debe ver el historial de sus documentos'; end if;
  reset role;
  perform public.tt_act('00000000-0000-0000-0000-000000000c02');
  select count(*) into cnt from public.document_events where contractor_id = n;
  if cnt <> 0 then raise exception 'FALLÓ [5.6]: otro contratista ve el historial ajeno'; end if;
  reset role;
  set local role anon;
  failed := false;
  begin perform count(*) from public.documents; exception when insufficient_privilege then failed := true; end;
  reset role;
  if not failed then raise exception 'FALLÓ [5.7]: un visitante anónimo accedió a documentos'; end if;
end $$;

-- ===== Grupo 6: lista de requisitos con su estado =====
do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000aaaa';
  n constant uuid := '00000000-0000-0000-0000-00000000a001';
  k constant uuid := '00000000-0000-0000-0000-00000000a002';
  w1 constant uuid := '00000000-0000-0000-0000-0000000000f1';
  t_exam uuid := public.tt_type(a, 'Examen médico ocupacional');
  r record; cnt integer; failed boolean; st text; doc uuid;
begin
  -- Persona natural: 16 requisitos, 8 por contrato
  perform public.tt_act('00000000-0000-0000-0000-000000000c01');
  select count(*) into cnt from public.contractor_requirements(n);
  if cnt <> 16 then raise exception 'FALLÓ [6.1]: la persona natural debe tener 16 requisitos y tiene %', cnt; end if;
  select count(*) into cnt from public.contractor_requirements(n) where status = 'by_contract';
  if cnt <> 8 then raise exception 'FALLÓ [6.2]: deben ser 8 requisitos por contrato y son %', cnt; end if;
  select status into st from public.contractor_requirements(n) where name = 'RUT actualizado';
  if st <> 'approved' then raise exception 'FALLÓ [6.3]: el RUT debe figurar aprobado y figura %', st; end if;
  select status into st from public.contractor_requirements(n) where name = 'Certificación bancaria';
  if st <> 'in_review' then raise exception 'FALLÓ [6.4]: la certificación debe figurar en revisión y figura %', st; end if;
  select status into st from public.contractor_requirements(n) where name = 'Documento de identidad';
  if st <> 'missing' then raise exception 'FALLÓ [6.5]: el documento de identidad debe figurar faltante y figura %', st; end if;
  select count(*) into cnt from public.contractor_requirements(n) where name = 'Examen médico ocupacional' and worker_id is null;
  if cnt <> 1 then raise exception 'FALLÓ [6.6]: para una persona natural el examen es una sola fila sin trabajador'; end if;

  -- Acceso
  failed := false;
  begin perform count(*) from public.contractor_requirements(k); exception when insufficient_privilege then failed := true; end;
  if not failed then raise exception 'FALLÓ [6.7]: un contratista consultó los requisitos de otro'; end if;
  reset role;
  perform public.tt_act('00000000-0000-0000-0000-000000000c03');
  failed := false;
  begin perform count(*) from public.contractor_requirements(n); exception when insufficient_privilege then failed := true; end;
  if not failed then raise exception 'FALLÓ [6.8]: un contratista de otra empresa consultó requisitos ajenos'; end if;
  reset role;
  set local role anon;
  failed := false;
  begin perform count(*) from public.contractor_requirements(n); exception when insufficient_privilege then failed := true; end;
  reset role;
  if not failed then raise exception 'FALLÓ [6.9]: un visitante anónimo consultó requisitos'; end if;

  -- Empresa contratista: trabajadores activos expanden los documentos de trabajador (4 tipos x 2 trabajadores)
  perform public.tt_act('00000000-0000-0000-0000-000000000a03');
  select count(*) into cnt from public.contractor_requirements(k);
  if cnt <> 13 + 8 then raise exception 'FALLÓ [6.10]: la empresa debe tener 21 filas y tiene %', cnt; end if;
  select count(*) into cnt from public.contractor_requirements(k) where worker_name = 'Luis';
  if cnt <> 0 then raise exception 'FALLÓ [6.11]: aparece un trabajador inactivo'; end if;
  select status into st from public.contractor_requirements(k) where name = 'Examen médico ocupacional' and worker_id = w1;
  if st <> 'in_review' then raise exception 'FALLÓ [6.12]: el examen del trabajador debe figurar en revisión y figura %', st; end if;
  select status, rejection_reason into r from public.contractor_requirements(k) where name = 'Curso de trabajo en alturas' and worker_id = w1;
  if r.status <> 'rejected' or r.rejection_reason <> 'Documento vencido' then raise exception 'FALLÓ [6.13]: el curso rechazado debe mostrar su motivo: %', r; end if;
  reset role;

  -- Vigencia: por vencer / vencido / vigente (alertas por defecto: hasta 30 días)
  doc := (select id from public.documents where contractor_id = n and document_type_id = t_exam and status = 'approved');
  update public.documents set expires_on = current_date + 10 where id = doc;
  perform public.tt_act('00000000-0000-0000-0000-000000000a01');
  select status into st from public.contractor_requirements(n) where name = 'Examen médico ocupacional';
  if st <> 'expiring_soon' then raise exception 'FALLÓ [6.14]: debe figurar por vencer y figura %', st; end if;
  reset role;
  update public.documents set expires_on = current_date - 1 where id = doc;
  perform public.tt_act('00000000-0000-0000-0000-000000000a01');
  select status into st from public.contractor_requirements(n) where name = 'Examen médico ocupacional';
  if st <> 'expired' then raise exception 'FALLÓ [6.15]: debe figurar vencido y figura %', st; end if;
  reset role;
  update public.documents set expires_on = current_date + 200 where id = doc;

  -- Renovación rechazada: el documento sigue vigente, pero se informa el motivo
  perform public.tt_act('00000000-0000-0000-0000-000000000c01');
  perform public.tt_ins(a, n, t_exam, null, current_date - 2, current_date + 300);
  select status into st from public.contractor_requirements(n) where name = 'Examen médico ocupacional';
  if st <> 'in_review' then raise exception 'FALLÓ [6.16]: con una renovación pendiente debe figurar en revisión y figura %', st; end if;
  reset role;
  perform public.tt_act('00000000-0000-0000-0000-000000000a02');
  perform public.tt_rev((select id from public.documents where contractor_id = n and document_type_id = t_exam and status = 'in_review'), 'rejected', null, null, null, 'Firma ilegible');
  select status, rejection_reason into r from public.contractor_requirements(n) where name = 'Examen médico ocupacional';
  if r.status <> 'approved' or r.rejection_reason <> 'Firma ilegible' then raise exception 'FALLÓ [6.17]: si rechazan la renovación debe seguir vigente y mostrar el motivo: %', r; end if;
  reset role;
end $$;

-- ===== Grupo 7: protecciones de borrado (como superadmin) =====
do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000aaaa';
  failed boolean;
begin
  failed := false;
  begin delete from public.document_types where company_id = a and name = 'Certificación bancaria'; exception when foreign_key_violation then failed := true; end;
  if not failed then raise exception 'FALLÓ [7.1]: se borró un documento del catálogo que tiene archivos'; end if;
  failed := false;
  begin delete from public.workers where id = '00000000-0000-0000-0000-0000000000f1'; exception when foreign_key_violation then failed := true; end;
  if not failed then raise exception 'FALLÓ [7.2]: se borró un trabajador con documentos'; end if;

  delete from public.companies where id = a;
  if exists (select 1 from public.documents where company_id = a) or exists (select 1 from public.document_events where company_id = a) then
    raise exception 'FALLÓ [7.3]: al eliminar la empresa quedaron documentos o historial huérfanos';
  end if;
end $$;

rollback;

select 'OK: todas las pruebas de documentos (semana 4) pasaron' as resultado;
