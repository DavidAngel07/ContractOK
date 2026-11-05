// Todos los textos de la interfaz viven aquí. Más adelante se pueden agregar otros idiomas.
export const es = {
  appName: 'ContractOK',
  skipToContent: 'Saltar al contenido',
  loading: 'Cargando…',
  login: {
    title: 'Iniciar sesión',
    subtitle: 'Ingresa con tu correo y contraseña.',
    email: 'Correo electrónico',
    password: 'Contraseña',
    submit: 'Ingresar',
    submitting: 'Ingresando…',
    invalidCredentials: 'Correo o contraseña incorrectos.',
    unconfirmed: 'Tu correo aún no está confirmado.',
    generic: 'No pudimos iniciar sesión. Inténtalo de nuevo.',
  },
  layout: {
    signOut: 'Cerrar sesión',
    signedInAs: 'Sesión de',
  },
  home: {
    title: 'Tu cuenta',
    greeting: (name: string) => `Hola, ${name}`,
    companySection: 'Empresa y rol',
    company: 'Empresa',
    role: 'Rol',
    responsibilities: 'Responsabilidades',
    scopeAll: 'Todos los contratistas',
    scopeAssigned: 'Solo los asignados',
    noCompany: 'Tu usuario todavía no pertenece a ninguna empresa. Pide al administrador que te agregue.',
    loadError: 'No pudimos cargar tu información.',
    noResponsibilities: 'Este rol no tiene responsabilidades asignadas.',
  },
  configMissing: {
    title: 'Falta configurar la conexión',
    body: 'Crea el archivo .env.local en la raíz del proyecto con VITE_SUPABASE_URL y VITE_SUPABASE_PUBLISHABLE_KEY, y reinicia el servidor (npm run dev).',
  },
} as const
