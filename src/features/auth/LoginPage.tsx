import { useState, type FormEvent } from 'react'
import { Navigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { useAuth } from './AuthProvider'

export function LoginPage() {
  const { session, loading } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  if (!loading && session) return <Navigate to="/" replace />

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setError(null)
    setSubmitting(true)
    const { error: authError } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    })
    setSubmitting(false)
    if (authError) {
      const message = authError.message.toLowerCase()
      if (message.includes('invalid login credentials')) setError(es.login.invalidCredentials)
      else if (message.includes('not confirmed')) setError(es.login.unconfirmed)
      else setError(es.login.generic)
    }
  }

  return (
    <main className="min-h-screen flex items-center justify-center p-4">
      <div className="w-full max-w-md rounded-2xl border border-line bg-surface p-8 shadow-sm">
        <p className="text-2xl font-extrabold tracking-tight">
          Contract<span className="text-accent">OK</span>
        </p>
        <h1 className="mt-6 text-2xl font-bold tracking-tight">{es.login.title}</h1>
        <p className="mt-1 text-muted">{es.login.subtitle}</p>

        <form onSubmit={handleSubmit} className="mt-6 flex flex-col gap-4" noValidate>
          <div>
            <label htmlFor="email" className="mb-1.5 block text-sm font-bold">
              {es.login.email}
            </label>
            <input
              id="email"
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="min-h-11 w-full rounded-lg border border-line bg-bg px-3 text-base"
            />
          </div>
          <div>
            <label htmlFor="password" className="mb-1.5 block text-sm font-bold">
              {es.login.password}
            </label>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="min-h-11 w-full rounded-lg border border-line bg-bg px-3 text-base"
            />
          </div>

          <div aria-live="polite">
            {error && (
              <p role="alert" className="rounded-lg bg-danger-bg px-3 py-2 text-sm font-bold text-danger">
                {error}
              </p>
            )}
          </div>

          <button
            type="submit"
            disabled={submitting || !email || !password}
            className="min-h-11 rounded-lg bg-accent px-5 font-bold text-accent-ink disabled:opacity-60"
          >
            {submitting ? es.login.submitting : es.login.submit}
          </button>
        </form>
      </div>
    </main>
  )
}
