// Volver al lugar de origen (por ejemplo, el asistente de configuración) después de editar algo.
// Solo se aceptan rutas internas, para evitar redirecciones a otros sitios.
export function safeReturn(value: string | null | undefined, fallback: string) {
  if (value && value.startsWith('/') && !value.startsWith('//') && !value.includes('\\')) return value
  return fallback
}

export function withReturn(path: string, returnTo?: string) {
  return returnTo ? `${path}?return=${encodeURIComponent(returnTo)}` : path
}
