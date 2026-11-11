import { useEffect, useState, type FormEvent } from 'react'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { isValidEmail } from '../contractors/utils'
import { isValidCode, mapSendError, mapVerifyError, normalizeCode } from './otp'

type Props = {
  shouldCreateUser: boolean
  emailHint?: string | null
  onVerified: () => void | Promise<void>
}

const COOLDOWN = 60

export function OtpForm({ shouldCreateUser, emailHint, onVerified }: Props) {
  const [step, setStep] = useState<'email' | 'code'>('email')
  const [email, setEmail] = useState('')
  const [code, setCode] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [cooldown, setCooldown] = useState(0)
  const t = es.otp

  useEffect(() => {
    if (cooldown <= 0) return
    const id = window.setInterval(() => setCooldown((s) => s - 1), 1000)
    return () => window.clearInterval(id)
  }, [cooldown])

  async function sendCode(event?: FormEvent) {
    event?.preventDefault()
    setError(null)
    if (!isValidEmail(email)) {
      setError(t.emailInvalid)
      return
    }
    setBusy(true)
    const { error: err } = await supabase.auth.signInWithOtp({
      email: email.trim().toLowerCase(),
      options: { shouldCreateUser },
    })
    setBusy(false)
    if (err) {
      setError(mapSendError(err))
      return
    }
    setStep('code')
    setCode('')
    setCooldown(COOLDOWN)
  }

  async function verify(event: FormEvent) {
    event.preventDefault()
    setError(null)
    if (!isValidCode(code)) {
      setError(t.codeInvalid)
      return
    }
    setBusy(true)
    const { error: err } = await supabase.auth.verifyOtp({
      email: email.trim().toLowerCase(),
      token: normalizeCode(code),
      type: 'email',
    })
    if (err) {
      setBusy(false)
      setError(mapVerifyError(err))
      return
    }
    await onVerified()
    setBusy(false)
  }

  const errorBox = (
    <div aria-live="polite">
      {error && (
        <p role="alert" className="rounded-xl bg-danger-bg px-3 py-2 text-sm font-bold text-danger">
          {error}
        </p>
      )}
    </div>
  )

  if (step === 'email') {
    return (
      <form onSubmit={sendCode} noValidate className="flex flex-col gap-4">
        <div>
          <label htmlFor="otp-email" className="mb-1.5 block text-sm font-bold">
            {t.emailLabel}
          </label>
          <input
            id="otp-email"
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            aria-describedby={emailHint ? 'otp-email-help' : undefined}
            className="field"
          />
          {emailHint && (
            <p id="otp-email-help" className="mt-1.5 text-sm text-muted">
              {t.emailHelp(emailHint)}
            </p>
          )}
        </div>
        {errorBox}
        <button type="submit" disabled={busy || !email} className="btn btn-primary">
          {busy ? t.sending : t.send}
        </button>
      </form>
    )
  }

  return (
    <form onSubmit={verify} noValidate className="flex flex-col gap-4">
      <p role="status" className="text-sm text-muted">
        {t.sent(email.trim().toLowerCase())}
      </p>
      <div>
        <label htmlFor="otp-code" className="mb-1.5 block text-sm font-bold">
          {t.codeLabel}
        </label>
        <input
          id="otp-code"
          inputMode="numeric"
          autoComplete="one-time-code"
          value={code}
          onChange={(e) => setCode(normalizeCode(e.target.value))}
          className="field text-center text-2xl font-bold tracking-widest"
        />
      </div>
      {errorBox}
      <button type="submit" disabled={busy || code.length < 6} className="btn btn-primary">
        {busy ? t.verifying : t.verify}
      </button>
      <div className="flex flex-wrap justify-between gap-2">
        <button type="button" onClick={() => sendCode()} disabled={busy || cooldown > 0} className="btn btn-secondary btn-sm">
          {cooldown > 0 ? t.resendIn(cooldown) : t.resend}
        </button>
        <button type="button" onClick={() => { setStep('email'); setError(null) }} className="btn btn-secondary btn-sm">
          {t.changeEmail}
        </button>
      </div>
    </form>
  )
}
