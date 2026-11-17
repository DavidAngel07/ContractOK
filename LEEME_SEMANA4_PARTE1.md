# ContractOK · Semana 4 · Parte 1: documentos, revisión y almacenamiento seguro

3 migraciones y 2 scripts de pruebas. Todavía no hay pantallas: llegan en las partes 2 a 4.

## Qué crea
- **`documents`**: cada archivo cargado para un requisito de un contratista (o de uno de sus trabajadores). Estados: pendiente de
  revisión, aprobado, rechazado y reemplazado. Guarda las fechas que declara quien sube (`declared_*`) y las que confirma el revisor
  (`issued_on`, `expires_on`, que serán las que usen las alertas). Deja columnas listas para la lectura con IA futura.
- **`document_events`**: historial de cada carga, aprobación, rechazo y reemplazo. Solo se agregan filas.
- **Bucket privado `documents`** (máx. 10 MB; solo PDF, JPG y PNG). Los archivos van en `<empresa>/<contratista>/<archivo>`.
- **Reglas de subida** (en la base de datos, no se pueden saltar desde la app): el documento debe estar en el perfil del contratista y
  activo; los de trabajador piden el trabajador (empresa contratista) o son del propio contratista (persona natural); se exigen las
  fechas que el documento pida; el estado, las fechas confirmadas y la revisión nunca los decide quien sube.
- **`review_document`**: aprobar o rechazar. Rechazar exige motivo. Al aprobar se validan las fechas (no vencido, no supera la antigüedad
  máxima; si el documento tiene antigüedad máxima y no vence, el vencimiento se calcula como emisión + días).
- **`contractor_requirements`**: la lista de requisitos de un contratista con el estado de cada uno: faltante, en revisión, aprobado,
  por vencer, vencido, rechazado, o «por contrato» (se carga por contrato, semana 6). Para empresas contratistas expande los
  documentos de trabajador por cada trabajador activo.

## Decisiones que conviene conocer
- **Renovaciones:** subir una versión nueva mientras hay una aprobada NO deja al contratista sin documento válido: la anterior sigue vigente
  hasta que se apruebe la nueva (entonces pasa a «reemplazado»). Si la renovación se rechaza, el documento sigue vigente y se informa el motivo.
  Subir otro archivo mientras hay uno pendiente reemplaza al pendiente.
- **Documentos «por contrato»** (cuenta de cobro, PILA mensual, informe, acta de cierre, etc.): la base ya los rechaza con un mensaje claro;
  se habilitan en la semana 6, cuando existan los contratos.
- **Nada se borra ni se edita desde la app:** ni documentos ni historial ni archivos. Un documento del catálogo con archivos cargados se
  desactiva en lugar de eliminarse. Un trabajador con documentos se marca como inactivo en lugar de quitarse
  (la pantalla de trabajadores del portal se ajusta en la parte 2).
- Carga asistida: el personal con «Cargar documentos en nombre de un contratista» puede subir; queda registrado como `assisted`.

## Qué se probó antes de entregarlo
- Sobre una base PostgreSQL 16 que simula Supabase, con las migraciones de las semanas 1 a 4: las 7 suites pasan juntas.
- Se rompió a propósito cada una de 6 reglas (carga asistida abierta, perfil ignorado, permiso de revisión ignorado, lectura de archivos
  abierta, requisitos de otros abiertos, modificación directa de documentos) y las pruebas fallaron como debían. Una de ellas reveló que
  la prueba 1.4 pasaba por la razón equivocada; se reforzó.
- LÍMITE: el almacenamiento se probó contra una réplica simplificada del esquema `storage` (no contra el servicio real de Supabase
  Storage). Por eso existe `week4_storage.sql`: es la comprobación real en TU proyecto (paso 4).

## Pasos
1. Copia las 3 migraciones de `supabase/migrations/` junto a las anteriores y los 2 archivos de `supabase/tests/` a `supabase/tests/`.
2. `npx supabase db push --remote --dry-run` (debe listar SOLO las 3 migraciones nuevas) y luego `npx supabase db push --remote`.
3. Editor SQL de Supabase (contractok-dev): pega TODO `week4_documents.sql` > Run. Esperado:
   «OK: todas las pruebas de documentos (semana 4) pasaron».
4. Pega TODO `week4_storage.sql` > Run. Esperado: «OK: todas las pruebas del almacenamiento de archivos (semana 4) pasaron».
   Si falla por algo que no empiece con «FALLÓ» (por ejemplo un permiso del esquema `storage`), copia el mensaje completo y me lo pasas:
   puede ser una diferencia de tu versión de Supabase Storage con mi réplica.
5. En Supabase > Storage debe aparecer el bucket `documents` marcado como privado.
6. `git add .`, `git commit -m "Semana 4 parte 1: documentos, revisión y almacenamiento"`, `git push`.
