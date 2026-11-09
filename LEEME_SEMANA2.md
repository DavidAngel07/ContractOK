# ContractOK · Semana 2 · Parte 1: base de datos de contratistas e invitaciones

Contiene 4 migraciones nuevas y un script de pruebas. Se ejecutaron antes de entregarse en una base PostgreSQL 16 que
simula a Supabase, partiendo de cero con las migraciones de la semana 1 y la semana 2. Las pruebas de la semana 1 siguen
pasando (regresión), y se comprobó que las pruebas de la semana 2 fallan cuando se rompe a propósito una regla de seguridad.
La prueba real contra tu proyecto es el paso 3.

## Qué crea
- Tablas: contractors, contractor_members, contractor_assignments, workers, invitations.
- Contratistas de tipo `natural` o `company`. Solo las empresas tienen trabajadores.
- Los contratistas NO se borran: se archivan (archived_at). Correo y NIT únicos por empresa entre los no archivados.
- Responsabilidades con alcance «asignados»: el supervisor solo ve los contratistas que tenga asignados.
- Invitaciones: el token (64 caracteres) se entrega UNA sola vez a quien invita; en la base solo se guarda su hash.
  Una sola invitación vigente por contratista (al crear otra, la anterior se anula).
- El contratista reclama su invitación solo si tiene el token Y su sesión (código al correo) corresponde al correo invitado.
- Funciones: create_invitation, revoke_invitation, get_invitation_preview (pública), claim_invitation y my_contractor_portal.

## Pasos (terminal de VS Code, en la raíz de tu proyecto)
1. Copia las 4 migraciones de `supabase/migrations/` de este paquete a la misma carpeta de tu proyecto
   (deben quedar junto a las 5 de la semana 1) y `supabase/tests/week2_rls.sql` a `supabase/tests/`.
2. Simula:  `npx supabase db push --remote --dry-run`  (debe listar SOLO las 4 migraciones nuevas)
   Aplica:  `npx supabase db push --remote`
3. Pruebas: Editor SQL de Supabase (contractok-dev) > pega TODO `supabase/tests/week2_rls.sql` > Run.
   Resultado esperado: «OK: todas las pruebas de la semana 2 pasaron».
   Si ves un error que empieza con «FALLÓ», copia el mensaje completo y pásamelo.
   (Opcional: vuelve a ejecutar `week1_rls.sql`; también debe seguir diciendo OK.)
4. Guarda: `git add .`  `git commit -m "Semana 2: base de datos de contratistas"`  `git push`

## Cosas que debes saber
- Desde el cliente no se puede leer la columna `token_hash` de invitaciones (a propósito). Al consultar invitaciones desde la
  aplicación hay que pedir columnas concretas, no `select *`.
- El correo por defecto de Supabase sirve solo para pruebas: está limitado a muy pocos mensajes por hora. Antes de probar con
  contratistas reales hay que configurar un proveedor de correo propio (SMTP). Lo prepararemos con la parte 3.
- Aplica esto solo a contractok-dev.
