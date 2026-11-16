# ContractOK · Semana 3 · Parte 3: asistente de configuración inicial

No hay migraciones nuevas ni librerías nuevas: solo la carpeta `src/` (reemplaza la existente).

## Qué hace
- **Asistente de 6 pasos** en `/setup`: 1 Empresa, 2 Documentos, 3 Perfiles de requisitos, 4 Roles, 5 Usuarios, 6 Revisión.
  Reutiliza las pantallas de Configuración que ya probaste. En el paso 1 el botón es «Guardar y continuar».
- **Guarda tu avance**: puedes salir («Salir y continuar después») y retomarlo donde quedaste. Solo puedes saltar a pasos a los que ya llegaste;
  los anteriores siempre se pueden revisar.
- **El administrador de una empresa nueva entra directo al asistente** la primera vez. Después, mientras no lo termine, ve un aviso
  en el Dashboard («Termina la configuración inicial») para retomarlo.
- Al crear o editar un documento o un perfil desde el asistente, **vuelves al asistente** (no a Configuración).
- **Revisión final**: resumen (documentos activos, perfiles activos, roles, personas) y lista de verificación. Para finalizar se exige
  al menos un documento activo y un perfil activo que exija algún documento. Las demás cosas son avisos, no bloqueos.
- Al finalizar, la empresa queda como «completada»: el asistente deja de mostrarse y pasas al Dashboard.
- Quien no puede gestionar usuarios (pasos 4 y 5) ve un aviso y puede seguir.

## Qué se probó antes de entregarlo
- Con el cliente real `supabase-js` contra una API sobre tu esquema: lectura del estado, guardado del avance, finalización, rechazo de un
  paso negativo, que un rol sin permiso no pueda alterarlo, y los conteos de la revisión.
- Todos los pasos y el aviso se renderizaron con datos de ejemplo; se probó la lógica de qué paso mostrar, de a dónde enviar al ingresar
  y que los retornos solo acepten rutas internas. Las pantallas de Configuración siguen funcionando por su ruta normal.
- NO se probó en un navegador. Eso lo pruebas tú.

## Pasos
1. Copia la carpeta `src/` a la raíz de tu proyecto, reemplazando lo existente. `npm run dev`.
2. TU EMPRESA DE DESARROLLO YA EXISTE y está en «no iniciada»: al ingresar como administrador te llevará al asistente.
   (Si quieres repetir la prueba desde cero, en el Editor SQL de Supabase:
   `update public.companies set setup_status = 'not_started', setup_step = 0;`)
3. Recorre los 6 pasos:
   - Paso 1: cambia algo y pulsa «Guardar y continuar». Debe pasar al paso 2.
   - Pasos 2 y 3: abre un documento/perfil, edítalo y guarda: debes volver al mismo paso del asistente.
   - Pasos 4 y 5: roles y usuarios funcionan dentro del asistente.
   - Haz clic en «Salir y continuar después», ve al Dashboard: debe aparecer el aviso con el paso en que ibas. Pulsa «Continuar configuración».
   - Paso 6: si desactivas todos los documentos (paso 2), «Finalizar» queda desactivado y se explica por qué. Actívalos de nuevo y finaliza.
4. Después de finalizar: el aviso desaparece, y el menú «Configuración» sigue permitiendo cambiar todo.
5. Crea una empresa nueva para ver la experiencia de un cliente nuevo (en el Editor SQL):
   `insert into public.companies (name) values ('Empresa de prueba 2');`
   y agrega un usuario con `select public.add_member(<id de la empresa>, <id del usuario>, 'Administrador');`
6. `git add .`, `git commit -m "Semana 3 parte 3: asistente de configuración inicial"`, `git push`.

## Nota
Esto completa la semana 3. Lo siguiente (semana 4) es el portal de carga de documentos del contratista.
