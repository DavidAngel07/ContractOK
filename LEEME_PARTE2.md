# ContractOK · Semana 2 · Parte 2: pantallas de la empresa

Lista de contratistas, formulario de invitación, ficha del contratista y menú de navegación.
No agrega librerías nuevas. Se compiló sin errores y sus consultas se probaron contra una API PostgREST real (la que usa
Supabase) sobre una base con tus migraciones: crear, listar, invitar, anular, archivar, correo duplicado y usuario de solo lectura.
No pude abrir la interfaz en un navegador; esa prueba es tuya (paso 3).

## Pasos
1. Copia la carpeta `src/` de este paquete a la raíz de tu proyecto y **reemplaza** los archivos existentes cuando pregunte
   (cambian App.tsx, AppLayout.tsx, HomePage.tsx, es.ts y styles.css; el resto son archivos nuevos).
2. Arranca: `npm run dev` y abre http://localhost:5173
3. Pruébalo con tu usuario administrador:
   - En el menú aparece «Contratistas». La lista empieza vacía.
   - «Invitar contratista»: crea uno de tipo persona natural y otro de tipo empresa. Prueba con el correo vacío y mal escrito
     (debe mostrar errores) y repite un correo ya usado (debe decir que ya existe).
   - Al crear, aparece el enlace de invitación: prueba «Copiar enlace» y «Enviar por correo» (abre tu programa de correo).
     El enlace se muestra UNA sola vez.
   - Abre la ficha: genera un nuevo enlace (el anterior queda «Anulada»), anula uno vigente y archiva un contratista.
   - Abre el enlace copiado: por ahora muestra «Invitación recibida» (el portal llega en la parte 3).
4. Prueba con un usuario con rol «Consulta»: ve la lista y las fichas, pero NO ve «Invitar contratista», ni los botones de la ficha;
   si escribe la dirección /contractors/new a mano, ve el mensaje de falta de permiso.
5. Comprueba que compila: `npm run build`. Luego `git add .`, `git commit -m "Semana 2: pantallas de contratistas"`, `git push`.

## Notas
- El enlace usa la dirección desde donde abres la app (localhost ahora; tu dominio cuando la publiquemos).
- «Archivar» pide confirmación y el contratista deja de aparecer en la lista (no se borra).
- Si algo falla, abre la consola del navegador (F12) y pásame el error completo.
