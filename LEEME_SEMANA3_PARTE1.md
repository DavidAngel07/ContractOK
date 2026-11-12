# ContractOK · Semana 3 · Parte 1: base de datos del asistente de configuración

4 migraciones + 1 script de pruebas. Se probaron sobre una base PostgreSQL 16 que simula Supabase, junto con las migraciones y
pruebas de las semanas 1 y 2 (las 4 suites pasan juntas), y se comprobó que las pruebas nuevas fallan si se rompen a propósito
la protección del catálogo o la verificación del correo en la invitación del personal.
La prueba real contra tu proyecto es el paso 3.

## Qué crea
- **Catálogo de documentos por empresa** (`document_types`): nombre, instrucciones, de quién es (contratista o trabajador),
  si se carga una vez o por contrato, fase, periodicidad, si pide fechas, antigüedad máxima, años de conservación,
  categoría de alerta (operativa o de cumplimiento) y a quién avisar.
- **Perfiles de requisitos** (`requirement_profiles` y `requirement_profile_items`): qué documentos exige cada tipo de contratista
  y cuáles son obligatorios. Cada contratista puede tener uno asignado (`contractors.requirement_profile_id`); debe ser de su empresa
  y servir para su tipo (persona natural o empresa).
- **Catálogo inicial**: toda empresa nueva (y las que ya existen, como la de tu entorno de desarrollo) recibe 19 documentos del
  informe y 3 perfiles de ejemplo, todos editables.
- **Invitación del personal** (`staff_invitations`): el administrador indica correo y rol; la persona entra con un código a su correo
  y su invitación se activa sola si el correo coincide. Sin contraseñas que definir ni compartir.
- Seguridad por filas: todo el personal lee el catálogo; solo quien tiene «Configurar la empresa» lo modifica.

## Reglas
- Un documento que está en un perfil no se elimina (se desactiva o se quita del perfil). Un perfil asignado a contratistas tampoco.
- `owner_kind = worker`: documento de quien presta el servicio en sitio: cada trabajador de una empresa contratista o, si el
  contratista es persona natural, el propio contratista.
- Los documentos «de contrato» se cargan por contrato; los «del contratista» una sola vez y valen para todos sus contratos.
- Las invitaciones de personal vencen a los 30 días y una nueva anula la anterior para el mismo correo.

## SUPUESTOS que debes confirmar con tu cliente (todo es editable desde las pantallas que vienen)
Tu cliente aún no ha respondido estas tres preguntas, así que el catálogo inicial usa estos valores:
1. **Documentos operativos vs. de cumplimiento:** operativos (alertan al supervisor): cuenta de cobro/factura e informe de actividades.
   El resto es de cumplimiento (alertan al revisor, con copia al supervisor).
2. **Plazo de conservación:** 10 años en general y 20 años en documentos de SST de los trabajadores (afiliación ARL, examen
   médico, alturas, espacios confinados, licencia SST) y en la matriz de riesgos. Confírmalo con un abogado.
3. **Supervisor:** se asigna por contrato (semana 6).

## Pasos (terminal de VS Code, raíz de tu proyecto)
1. Copia las 4 migraciones de `supabase/migrations/` junto a las anteriores y `supabase/tests/week3_catalog.sql` a `supabase/tests/`.
2. `npx supabase db push --remote --dry-run` (debe listar SOLO las 4 migraciones nuevas) y luego `npx supabase db push --remote`.
3. Editor SQL de Supabase (contractok-dev): pega TODO `week3_catalog.sql` y ejecútalo. Esperado:
   «OK: todas las pruebas de la semana 3 (catálogo e invitaciones) pasaron».
   Si ves un error que empieza con «FALLÓ», copia el mensaje completo y pásamelo.
4. Comprueba que tu empresa de desarrollo recibió su catálogo (debe dar 19, 3 y 43):
   ```sql
   select
     (select count(*) from public.document_types) as documentos,
     (select count(*) from public.requirement_profiles) as perfiles,
     (select count(*) from public.requirement_profile_items) as requisitos;
   ```
   Si tienes más de una empresa, los números serán múltiplos de esos.
5. `git add .`, `git commit -m "Semana 3 parte 1: catálogo, perfiles e invitación de personal"`, `git push`.
