export type InvitationRow = {
  id: string
  email: string
  expires_at: string
  used_at: string | null
  revoked_at: string | null
  created_at: string
}
export type InvitationState = 'valid' | 'used' | 'revoked' | 'expired'

// Mismo orden de prioridad que get_invitation_preview en la base de datos.
export function invitationState(
  i: Pick<InvitationRow, 'expires_at' | 'used_at' | 'revoked_at'>,
  now: Date = new Date(),
): InvitationState {
  if (i.revoked_at) return 'revoked'
  if (i.used_at) return 'used'
  if (new Date(i.expires_at) < now) return 'expired'
  return 'valid'
}

export const buildInviteLink = (origin: string, token: string) => `${origin}/invite/${token}`

export function buildMailto(email: string, subject: string, body: string) {
  return `mailto:${encodeURIComponent(email)}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`
}

export function buildGmailUrl(email: string, subject: string, body: string) {
  return `https://mail.google.com/mail/?view=cm&fs=1&to=${encodeURIComponent(email)}&su=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`
}

export function buildOutlookUrl(email: string, subject: string, body: string) {
  return `https://outlook.live.com/mail/0/deeplink/compose?to=${encodeURIComponent(email)}&subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`
}

// Si el número tiene 10 dígitos se asume Colombia (57). Sin teléfono, WhatsApp deja elegir el chat.
export function buildWhatsAppUrl(phone: string | null | undefined, text: string) {
  const digits = (phone ?? '').replace(/\D/g, '')
  const full = digits.length === 10 ? `57${digits}` : digits
  const base = full.length >= 11 ? `https://wa.me/${full}` : 'https://wa.me/'
  return `${base}?text=${encodeURIComponent(text)}`
}

export type Tone = 'ok' | 'warn' | 'bad' | 'info' | 'neutral'

export const contractorStatusTone: Record<string, Tone> = {
  invited: 'neutral',
  filling: 'info',
  in_review: 'warn',
  observations: 'bad',
  enabled: 'ok',
  active: 'ok',
  closing: 'warn',
  closed: 'neutral',
}

export const invitationTone: Record<InvitationState, Tone> = {
  valid: 'ok',
  used: 'info',
  revoked: 'neutral',
  expired: 'bad',
}

export const isValidEmail = (value: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim())
