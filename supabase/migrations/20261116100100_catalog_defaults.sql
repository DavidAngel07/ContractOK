-- ContractOK · Semana 3 · Catálogo inicial y perfiles de ejemplo
-- Parten del informe de documentación por fases. Son SUPUESTOS editables por cada empresa
-- (clasificación operativa/cumplimiento, plazos de conservación y quién recibe las alertas).

create or replace function public.create_default_document_types(p_company_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into public.document_types
    (company_id, name, description, owner_kind, scope, phase, periodicity, requires_dates,
     max_age_days, retention_years, alert_category, alert_audience, sort_order)
  select p_company_id, v.name, v.description, v.owner_kind, v.scope, v.phase, v.periodicity, v.requires_dates,
         v.max_age_days, v.retention_years, v.alert_category,
         case v.alert_category when 'operational' then array['contractor', 'supervisor']
                               else array['contractor', 'reviewer', 'supervisor'] end,
         v.sort_order
  from (values
    -- Fase 1 · Contratación
    ('Contrato firmado', 'Contrato de prestación de servicios firmado por ambas partes', 'contractor', 'contract', 'contracting', 'once', false, null::integer, 10, 'compliance', 10),
    ('Documento de identidad', 'Cédula, pasaporte, PPT o PEP (persona natural o representante legal)', 'contractor', 'contractor', 'contracting', 'once', false, null, 10, 'compliance', 20),
    ('RUT actualizado', 'Registro Único Tributario actualizado', 'contractor', 'contractor', 'contracting', 'once', false, null, 10, 'compliance', 30),
    ('Certificado de Cámara de Comercio', 'Solo personas jurídicas o comerciantes registrados', 'contractor', 'contractor', 'contracting', 'once', true, 90, 10, 'compliance', 40),
    ('Certificación bancaria', 'Para el pago de honorarios', 'contractor', 'contractor', 'contracting', 'once', false, null, 10, 'compliance', 50),
    ('Certificados de idoneidad', 'Diplomas, tarjetas profesionales o certificaciones de experiencia', 'contractor', 'contractor', 'contracting', 'once', false, null, 10, 'compliance', 60),
    -- Fase 2 · Mensual
    ('Cuenta de cobro o factura electrónica', 'Cuenta de cobro, o factura electrónica de venta si es responsable de IVA', 'contractor', 'contract', 'monthly', 'monthly', false, null, 10, 'operational', 110),
    ('Planilla PILA mensual', 'Soporte de pago de seguridad social del periodo', 'contractor', 'contract', 'monthly', 'monthly', false, null, 10, 'compliance', 120),
    ('Informe de actividades', 'Entregables del mes, firmado por el supervisor', 'contractor', 'contract', 'monthly', 'monthly', false, null, 10, 'operational', 130),
    -- Fase 3 · Seguridad y salud en el trabajo
    ('Afiliación a ARL', 'Certificado de afiliación emitido por la ARL', 'worker', 'contractor', 'sst', 'once', false, null, 20, 'compliance', 210),
    ('Examen médico ocupacional', 'Concepto de aptitud médica', 'worker', 'contractor', 'sst', 'expiring', true, null, 20, 'compliance', 220),
    ('Curso de trabajo en alturas', 'Certificado vigente, si la labor lo requiere', 'worker', 'contractor', 'sst', 'expiring', true, null, 20, 'compliance', 230),
    ('Curso de espacios confinados', 'Certificado vigente, si la labor lo requiere', 'worker', 'contractor', 'sst', 'expiring', true, null, 20, 'compliance', 240),
    ('Licencia en SST', 'Solo si fue contratado para temas de salud ocupacional', 'worker', 'contractor', 'sst', 'expiring', true, null, 20, 'compliance', 250),
    ('Póliza de responsabilidad civil', 'Póliza vigente de la empresa contratista', 'contractor', 'contractor', 'sst', 'expiring', true, null, 10, 'compliance', 260),
    ('Matriz de riesgos o plan de trabajo', 'Análisis de riesgos de la labor, si el servicio es operativo', 'contractor', 'contract', 'sst', 'once', false, null, 20, 'compliance', 270),
    ('Ficha técnica de equipos o herramientas', 'Si ingresa maquinaria propia a las instalaciones', 'contractor', 'contract', 'sst', 'once', false, null, 10, 'compliance', 280),
    -- Fase 4 · Cierre
    ('Acta de liquidación y cierre de contrato', 'Firmada por ambas partes; deja las cuentas a paz y salvo', 'contractor', 'contract', 'closing', 'closing', false, null, 10, 'compliance', 310),
    ('Planilla PILA de cierre (con novedad de retiro)', 'Verifica el reporte de la novedad de retiro', 'contractor', 'contract', 'closing', 'closing', false, null, 10, 'compliance', 320)
  ) as v(name, description, owner_kind, scope, phase, periodicity, requires_dates, max_age_days, retention_years, alert_category, sort_order);

  insert into public.requirement_profiles (company_id, name, description, contractor_kind) values
    (p_company_id, 'Persona natural · servicios profesionales', 'Consultores y profesionales independientes que no trabajan en sitio', 'natural'),
    (p_company_id, 'Persona natural · operativo en sitio', 'Técnicos o independientes que prestan el servicio en tus instalaciones', 'natural'),
    (p_company_id, 'Empresa contratista · personal en sitio', 'Empresas que envían trabajadores a tus instalaciones', 'company');

  insert into public.requirement_profile_items (requirement_profile_id, document_type_id, company_id, is_mandatory)
  select p.id, d.id, p_company_id, i.mandatory
  from (values
    ('Persona natural · servicios profesionales', 'Contrato firmado', true),
    ('Persona natural · servicios profesionales', 'Documento de identidad', true),
    ('Persona natural · servicios profesionales', 'RUT actualizado', true),
    ('Persona natural · servicios profesionales', 'Certificación bancaria', true),
    ('Persona natural · servicios profesionales', 'Certificados de idoneidad', true),
    ('Persona natural · servicios profesionales', 'Cuenta de cobro o factura electrónica', true),
    ('Persona natural · servicios profesionales', 'Planilla PILA mensual', true),
    ('Persona natural · servicios profesionales', 'Informe de actividades', true),
    ('Persona natural · servicios profesionales', 'Acta de liquidación y cierre de contrato', true),
    ('Persona natural · servicios profesionales', 'Planilla PILA de cierre (con novedad de retiro)', true),
    ('Persona natural · operativo en sitio', 'Contrato firmado', true),
    ('Persona natural · operativo en sitio', 'Documento de identidad', true),
    ('Persona natural · operativo en sitio', 'RUT actualizado', true),
    ('Persona natural · operativo en sitio', 'Certificación bancaria', true),
    ('Persona natural · operativo en sitio', 'Certificados de idoneidad', true),
    ('Persona natural · operativo en sitio', 'Cuenta de cobro o factura electrónica', true),
    ('Persona natural · operativo en sitio', 'Planilla PILA mensual', true),
    ('Persona natural · operativo en sitio', 'Informe de actividades', true),
    ('Persona natural · operativo en sitio', 'Afiliación a ARL', true),
    ('Persona natural · operativo en sitio', 'Examen médico ocupacional', true),
    ('Persona natural · operativo en sitio', 'Curso de trabajo en alturas', false),
    ('Persona natural · operativo en sitio', 'Curso de espacios confinados', false),
    ('Persona natural · operativo en sitio', 'Matriz de riesgos o plan de trabajo', true),
    ('Persona natural · operativo en sitio', 'Ficha técnica de equipos o herramientas', false),
    ('Persona natural · operativo en sitio', 'Acta de liquidación y cierre de contrato', true),
    ('Persona natural · operativo en sitio', 'Planilla PILA de cierre (con novedad de retiro)', true),
    ('Empresa contratista · personal en sitio', 'Contrato firmado', true),
    ('Empresa contratista · personal en sitio', 'Documento de identidad', true),
    ('Empresa contratista · personal en sitio', 'RUT actualizado', true),
    ('Empresa contratista · personal en sitio', 'Certificado de Cámara de Comercio', true),
    ('Empresa contratista · personal en sitio', 'Certificación bancaria', true),
    ('Empresa contratista · personal en sitio', 'Póliza de responsabilidad civil', false),
    ('Empresa contratista · personal en sitio', 'Cuenta de cobro o factura electrónica', true),
    ('Empresa contratista · personal en sitio', 'Planilla PILA mensual', true),
    ('Empresa contratista · personal en sitio', 'Informe de actividades', true),
    ('Empresa contratista · personal en sitio', 'Afiliación a ARL', true),
    ('Empresa contratista · personal en sitio', 'Examen médico ocupacional', true),
    ('Empresa contratista · personal en sitio', 'Curso de trabajo en alturas', false),
    ('Empresa contratista · personal en sitio', 'Curso de espacios confinados', false),
    ('Empresa contratista · personal en sitio', 'Matriz de riesgos o plan de trabajo', true),
    ('Empresa contratista · personal en sitio', 'Ficha técnica de equipos o herramientas', false),
    ('Empresa contratista · personal en sitio', 'Acta de liquidación y cierre de contrato', true),
    ('Empresa contratista · personal en sitio', 'Planilla PILA de cierre (con novedad de retiro)', true)
  ) as i(profile_name, doc_name, mandatory)
  join public.requirement_profiles p on p.company_id = p_company_id and p.name = i.profile_name
  join public.document_types d on d.company_id = p_company_id and d.name = i.doc_name;
end $$;

revoke execute on function public.create_default_document_types(uuid) from public, anon, authenticated;

-- Al crear una empresa: ajustes, roles, catálogo y perfiles (reemplaza la versión anterior).
create or replace function public.trg_company_defaults()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.company_settings (company_id) values (new.id);
  perform public.create_default_roles(new.id);
  perform public.create_default_document_types(new.id);
  return null;
end $$;

-- Empresas que ya existían (por ejemplo la del piloto en desarrollo): se les agrega el catálogo.
do $$
declare c uuid;
begin
  for c in select id from public.companies x
           where not exists (select 1 from public.document_types d where d.company_id = x.id)
  loop
    perform public.create_default_document_types(c);
  end loop;
end $$;
