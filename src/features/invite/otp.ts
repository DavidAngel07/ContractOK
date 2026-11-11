import { es } from '../../i18n/es'

// Los proyectos recientes de Supabase envían códigos de 8 dígitos (antes 6): se aceptan de 6 a 10.
export function normalizeCode(value: string) {
  return value.replace(/\D/g, '').slice(0, 10)
}
export const isValidCode = (value: string) => normalizeCode(value).length >= 6

type AuthLikeError = { status?: number; code?: string; message?: string }

export function mapSendError(error: AuthLikeError): string {
  const message = (error.message ?? '').toLowerCase()
  if (error.status === 429 || error.code === 'over_email_send_rate_limit' || error.code === 'over_request_rate_limit' || message.includes('rate limit') || message.includes('only request this after'))
    return es.otp.rateLimit
  if (message.includes('signups not allowed') || message.includes('user not found')) return es.otp.noAccount
  return es.otp.generic
}

export function mapVerifyError(error: AuthLikeError): string {
  const message = (error.message ?? '').toLowerCase()
  if (error.status === 429) return es.otp.rateLimit
  if (message.includes('expired') || message.includes('invalid')) return es.otp.wrongCode
  return es.otp.generic
}

// Misma pista que genera la base de datos para el correo invitado: primera letra + *** + @dominio.
export function emailHint(email: string) {
  const clean = email.trim().toLowerCase()
  return `${clean.slice(0, 1)}***@${clean.split('@')[1] ?? ''}`
}
