import { useEffect, useState } from 'react'
import { Link, Navigate, useNavigate, useSearchParams } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { Logo } from '../../components/Logo'
import { Notice } from '../../components/Notice'
import { useAuth } from '../auth/AuthProvider'
import { useAccount } from '../account/useAccount'
import { CompanyPage } from '../settings/CompanyPage'
import { DocumentsPage } from '../settings/DocumentsPage'
import { ProfilesPage } from '../settings/ProfilesPage'
import { RolesPage } from '../settings/RolesPage'
import { UsersPage } from '../settings/UsersPage'
import { SetupReview } from './SetupReview'
import { useSetupSummary } from './useSetupSummary'

const TOTAL = 6

// Paso que se muestra: el pedido en la dirección, sin pasar del último paso al que ya se llegó.
export function resolveStep(requested: string | null, reached: number) {
  const asked = Number(requested)
  const wanted = Number.isInteger(asked) && asked >= 1 ? asked : reached
  return Math.min(Math.max(wanted, 1), Math.min(Math.max(reached, 1), TOTAL))
}

export function SetupPage() {
  const { account, can, isLoading } = useAccount()
  const { session } = useAuth()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [search, setSearch] = useSearchParams()
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const summary = useSetupSummary(es.setup.review)
  const t = es.setup

  // La primera vez que se abre, la empresa pasa a «en curso» (así no se vuelve a enviar aquí al ingresar).
  const needsStart = account?.setupStatus === 'not_started'
  const companyId = account?.companyId
  useEffect(() => {
    if (!needsStart || !companyId) return
    supabase.from('companies').update({ setup_status: 'in_progress', setup_step: 1 }).eq('id', companyId)
      .then(() => queryClient.invalidateQueries({ queryKey: ['account-context'] }))
  }, [needsStart, companyId, queryClient])

  if (isLoading) return <p role="status" className="p-8 text-muted">{es.loading}</p>
  if (!account) return <Navigate to="/" replace />
  if (account.setupStatus === 'completed') return <Navigate to="/settings" replace />

  const reached = Math.max(account.setupStep, 1)
  const step = resolveStep(search.get('step'), reached)
  const info = t.steps[step - 1]
  const goTo = (n: number) => setSearch({ step: String(n) })

  async function advance(to: number) {
    setError(null)
    setBusy(true)
    const { error: e } = await supabase.from('companies')
      .update({ setup_step: Math.max(account!.setupStep, to), setup_status: 'in_progress' }).eq('id', account!.companyId)
    if (e) { setBusy(false); setError(t.saveError); return }
    await queryClient.invalidateQueries({ queryKey: ['account-context'] })
    setBusy(false)
    goTo(to)
  }

  async function finish() {
    setError(null)
    setBusy(true)
    const { error: e } = await supabase.from('companies').update({ setup_status: 'completed', setup_step: TOTAL }).eq('id', account!.companyId)
    if (e) { setBusy(false); setError(t.saveError); return }
    await queryClient.invalidateQueries({ queryKey: ['account-context'] })
    navigate('/dashboard', { replace: true })
  }

  const here = `/setup?step=${step}`
  const canManageUsers = can('users.manage')

  return (
    <div className="min-h-screen">
      <a href="#contenido" className="absolute -top-20 left-4 z-50 rounded-full bg-accent px-4 py-2 font-bold text-accent-ink focus:top-4">
        {es.skipToContent}
      </a>
      <header className="border-b border-line bg-surface">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-3 px-6 py-3">
          <Logo />
          <div className="flex items-center gap-3">
            <span className="hidden max-w-56 truncate text-sm text-muted sm:inline">{session?.user.email}</span>
            <Link to="/dashboard" className="btn btn-secondary btn-sm">{t.exit}</Link>
          </div>
        </div>
      </header>

      <main id="contenido" className="mx-auto flex max-w-5xl flex-col gap-6 px-6 py-8">
        <div>
          <p className="text-sm font-bold text-link">{t.title} · {t.stepOf(step, TOTAL)}</p>
          <h1 className="mt-1 text-3xl font-extrabold tracking-tight">{info.title}</h1>
          <p className="mt-1 max-w-3xl text-muted">{info.intro}</p>
        </div>

        <nav aria-label={t.stepperLabel}>
          <ol className="flex flex-wrap gap-2">
            {t.steps.map((s, i) => {
              const n = i + 1
              const done = n < reached || (n === reached && account.setupStep > n)
              const reachable = n <= reached
              const base = 'inline-flex min-h-11 items-center gap-2 rounded-full px-4 text-sm font-bold'
              const style = n === step ? 'bg-accent text-accent-ink' : reachable ? 'border border-line bg-surface' : 'border border-line text-muted opacity-60'
              return (
                <li key={s.label}>
                  {reachable ? (
                    <button type="button" onClick={() => goTo(n)} aria-current={n === step ? 'step' : undefined} className={`${base} ${style}`}>
                      <span aria-hidden="true">{done && n !== step ? '✓' : n}</span>{s.label}
                    </button>
                  ) : (
                    <span className={`${base} ${style}`} aria-disabled="true"><span aria-hidden="true">{n}</span>{s.label}</span>
                  )}
                </li>
              )
            })}
          </ol>
        </nav>

        <div>
          {step === 1 && <CompanyPage submitLabel={t.saveContinue} onSaved={() => advance(2)} />}
          {step === 2 && <DocumentsPage returnTo={here} />}
          {step === 3 && <ProfilesPage returnTo={here} />}
          {step === 4 && (canManageUsers ? <RolesPage /> : <Notice kind="info">{t.noPermission}</Notice>)}
          {step === 5 && (canManageUsers ? <UsersPage /> : <Notice kind="info">{t.noPermission}</Notice>)}
          {step === 6 && <SetupReview summary={summary} onGo={goTo} />}
        </div>

        <div aria-live="polite">{error && <Notice kind="error">{error}</Notice>}</div>
        <div className="flex flex-wrap items-center justify-between gap-3 border-t border-line pt-6">
          <div>{step > 1 && <button type="button" className="btn btn-secondary" disabled={busy} onClick={() => goTo(step - 1)}>{t.back}</button>}</div>
          {step > 1 && step < TOTAL && <button type="button" className="btn btn-primary" disabled={busy} onClick={() => advance(step + 1)}>{t.next}</button>}
          {step === TOTAL && (
            <button type="button" className="btn btn-primary" disabled={busy || summary.isLoading || summary.blockers.length > 0} onClick={finish}>
              {busy ? t.finishing : t.finish}
            </button>
          )}
        </div>
      </main>
    </div>
  )
}
