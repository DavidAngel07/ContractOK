# ContractOK · Semana 2 · Parte 3: portal del contratista

Incluye: enlace de invitación con código al correo, ingreso de contratistas, portal con «Tus datos» y «Trabajadores»,
y un arreglo de estilos (el aviso amarillo de la pantalla de invitación no tenía color).

## Qué se probó antes de entregarlo
- Base de datos: migración nueva + pruebas del portal (y se comprobó que fallan si se rompe la regla de pertenencia).
  Las pruebas de las semanas 1 y 2 siguen pasando.
- Flujo completo con el cliente real `supabase-js` contra una API PostgREST sobre tu esquema: crear contratista, invitar, vista
  previa pública, reclamar (correo correcto e incorrecto), portal, guardar datos, trabajadores y lo que el contratista NO puede hacer.
- La interfaz se compiló y se renderizó en servidor. NO se probó en un navegador ni con el envío real de correos de Supabase:
  eso lo pruebas tú (pasos 4 y 5).

## 1. Base de datos
1. Copia `supabase/migrations/20261112100000_contractor_portal.sql` a tu carpeta `supabase/migrations/` y
   `supabase/tests/week2_portal.sql` a `supabase/tests/`.
2. `npx supabase db push --remote --dry-run` (debe listar SOLO la migración nueva) y luego `npx supabase db push --remote`.
3. Editor SQL de Supabase: pega todo `week2_portal.sql` y ejecútalo. Resultado esperado: «OK: todas las pruebas del portal pasaron».

## 2. Aplicación
Copia las carpetas `src/` y `public/` de este paquete a la raíz del proyecto, reemplazando lo existente. No hay librerías nuevas.

## 3. Configurar el correo con código (IMPORTANTE, en Supabase)
Por defecto Supabase envía un ENLACE, no un código. Para que llegue el código hay que editar dos plantillas:
Supabase > Authentication > Email Templates (en algunos paneles: Authentication > Emails). Edita estas DOS plantillas:
- «Magic Link» (para quien ya tiene cuenta) y
- «Confirm signup» (para quien entra por primera vez con su invitación).
En ambas pon este asunto: `Tu código de acceso a contractOK` y este contenido:

```html
<h2>Tu código de acceso</h2>
<p>Usa este código para entrar a contractOK:</p>
<p style="font-size:28px;font-weight:bold;letter-spacing:4px">{{ .Token }}</p>
<p>El código vence en 1 hora. Si no lo pediste, ignora este mensaje.</p>
```
- El código puede ser de 6 u 8 dígitos según tu proyecto; la pantalla acepta de 6 a 10.
- En Authentication > URL Configuration, deja Site URL como http://localhost:5173 mientras pruebas.
- LÍMITE: el envío de correos por defecto de Supabase permite muy pocos mensajes por hora (alrededor de 2) y entre
  códigos hay que esperar 60 segundos. Para las pruebas basta, pero planea cada prueba. Antes del piloto hay que configurar
  un proveedor de correo propio (SMTP, por ejemplo Resend o Brevo).

## 4. Probar el flujo del contratista
Usa una ventana de incógnito para el contratista (así no se mezcla con tu sesión de administrador).
Truco: con Gmail puedes usar tu propio correo con un «+»: `tunombre+contratista1@gmail.com` llega a tu bandeja.
1. Como administrador, crea un contratista de tipo EMPRESA con ese correo y copia el enlace.
2. En la ventana de incógnito abre el enlace: debe mostrar «<tu empresa> te invita a cargar tu documentación» y el nombre.
3. Escribe el correo (la pantalla te da una pista) > «Enviar código» > escribe el código recibido > «Verificar».
   Debes llegar a «Hola, <nombre>» (el portal), con el estado «En diligenciamiento».
4. Completa «Tus datos», guarda, agrega 2 trabajadores (prueba repetir un documento) y quita uno. El avance se actualiza.
5. Como administrador, abre la ficha: debe mostrar los datos y los trabajadores que cargó.
6. Cierra sesión en el portal, entra por `/ingreso` con el mismo correo (segundo código) y verifica que vuelves a tu portal.
7. Enlaces especiales: anula una invitación desde la ficha y abre su enlace (debe decir «anulado»); abre un enlace con
   un carácter cambiado (debe decir «no es válido»); abre un enlace ya usado (debe ofrecer ingresar con tu correo).

## 5. Qué debes saber
- En la pantalla de la invitación, la persona escribe su correo. Aunque escriba otro, NO obtiene acceso: la invitación solo se
  activa si el correo coincide. Pero hoy cualquiera podría solicitar un código para un correo cualquiera y Supabase le crearía
  una cuenta vacía (sin acceso a nada). Más adelante lo cerramos con una función del servidor que envía el código solo al
  correo invitado, o con CAPTCHA.
- Los contratistas solo pueden editar sus datos mientras su estado sea invitado, en diligenciamiento o con observaciones.
- Los documentos (cédula, RUT, etc.) se suben en la semana 4; el portal ya muestra el espacio.
- `git add .`, `git commit -m "Semana 2: portal del contratista"`, `git push`.
