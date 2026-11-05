-- ContractOK · Semana 1 · Catálogo de responsabilidades (permisos)

insert into public.permissions (key, description) values
  ('company.configure', 'Configurar los datos y ajustes de la empresa'),
  ('users.manage', 'Gestionar usuarios, roles y responsabilidades'),
  ('contractors.manage', 'Invitar y editar contratistas'),
  ('documents.upload_on_behalf', 'Cargar documentos en nombre de un contratista'),
  ('documents.review', 'Revisar documentos (aprobar o rechazar)'),
  ('reports.activity_validate', 'Validar informes de actividades'),
  ('periods.manage', 'Ver el paquete mensual y marcarlo listo para pago'),
  ('reports.view', 'Ver reportes y exportar'),
  ('alerts.receive', 'Recibir alertas de vencimiento'),
  ('audit.view', 'Ver el historial de auditoría')
on conflict (key) do update set description = excluded.description;
