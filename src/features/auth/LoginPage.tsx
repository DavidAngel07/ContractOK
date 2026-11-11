import { useState, type FormEvent } from 'react'
import { Link, Navigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { Logo } from '../../components/Logo'
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
    const { error: authError } = await supabase.auth.signInWithPassword({ email: email.trim(), password })
    setSubmitting(false)
    if (authError) {
      const message = authError.message.toLowerCase()
      if (message.includes('invalid login credentials')) setError(es.login.invalidCredentials)
      else if (message.includes('not confirmed')) setError(es.login.unconfirmed)
      else setError(es.login.generic)
    }
  }

  const [before, after] = es.brand.heroTitle.split(es.brand.heroAccent)

  return (
    <div className="min-h-screen md:grid md:grid-cols-2">
      {/* Panel de marca (solo en pantallas medianas y grandes) */}
      <aside
        className="hidden flex-col justify-between p-12 text-white md:flex"
        style={{ background: 'linear-gradient(150deg, #1D1240 0%, #3B1A8C 55%, #5B21B6 100%)' }}
      >
        <Logo onDark size={48} />
        <div>
          <h2 className="max-w-md text-4xl leading-tight font-extrabold tracking-tight">
            {before}
            <span style={{ color: '#C4B5FD' }}>{es.brand.heroAccent}</span>
            {after}
          </h2>
          <p className="mt-4 max-w-md text-lg" style={{ color: '#E9D5FF' }}>
            {es.brand.heroBody}
          </p>
          <ul className="mt-8 grid max-w-md grid-cols-2 gap-3">
            {es.brand.pillars.map((p) => (
              <li key={p} className="rounded-2xl px-4 py-3 text-sm font-bold" style={{ background: 'rgb(255 255 255 / 0.1)' }}>
                {p}
              </li>
            ))}
          </ul>
        </div>
        <p className="text-lg font-bold">
          {es.brand.slogan.replace('más fuertes.', '')}
          <span style={{ color: '#C4B5FD' }}>más fuertes.</span>
        </p>
      </aside>

      <main className="flex min-h-screen items-center justify-center p-6 md:min-h-0">
        <div className="w-full max-w-md">
          <div className="mb-8 md:hidden">
            <Logo />
          </div>
          <div className="card p-8">
            <p className="text-sm font-bold text-link">{es.login.welcome}</p>
            <h1 className="mt-1 text-3xl font-extrabold tracking-tight">{es.login.title}</h1>
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
                  className="field"
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
                  className="field"
                />
              </div>

              <div aria-live="polite">
                {error && (
                  <p role="alert" className="rounded-xl bg-danger-bg px-3 py-2 text-sm font-bold text-danger">
                    {error}
                  </p>
                )}
              </div>

              <button type="submit" disabled={submitting || !email || !password} className="btn btn-primary">
                {submitting ? es.login.submitting : es.login.submit}
              </button>
            </form>
          </div>
          <p className="mt-6 text-center text-sm">
            <Link to="/ingreso" className="font-bold text-link underline">
              {es.contractorLogin.contractorLink}
            </Link>
          </p>
          <p className="mt-3 text-center text-sm text-muted">{es.brand.tagline}</p>
        </div>
      </main>
    </div>
  )
}
