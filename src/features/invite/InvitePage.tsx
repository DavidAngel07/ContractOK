import { useState, type ReactNode } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { Logo } from '../../components/Logo'
import { useAuth } from '../auth/AuthProvider'
import { OtpForm } from './OtpForm'
import { emailHint } from './otp'

type Preview = {
  state: 'valid' | 'used' | 'revoked' | 'expired' | 'invalid'
  company_name: string | null
  contractor_name: string | null
  email_hint: string | null
}

function Shell({ children }: { children: ReactNode }) {
  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <div className="w-full max-w-lg">
        <div className="mb-8">
          <Logo />
        </div>
        <div className="card p-8">{children}</div>
      </div>
    </main>
  )
}

function Message({ title, body, children }: { title: string; body: string; children?: ReactNode }) {
  return (
    <div className="flex flex-col gap-3">
      <h1 className="text-2xl font-extrabold tracking-tight">{title}</h1>
      <p className="text-muted">{body}</p>
      {children}
    </div>
  )
}

export function InvitePage() {
  const { token = '' } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { session, signOut } = useAuth()
  const [claiming, setClaiming] = useState(false)
  const [claimError, setClaimError] = useState<string | null>(null)
  const t = es.invite

  const preview = useQuery({
    queryKey: ['invite-preview', token],
    retry: false,
    queryFn: async () => {
      const { data, error } = await supabase.rpc('get_invitation_preview', { p_token: token })
      if (error) throw error
      const row = Array.isArray(data) ? data[0] : data
      return (row ?? { state: 'invalid', company_name: null, contractor_name: null, email_hint: null }) as Preview
    },
  })

  async function claim() {
    setClaimError(null)
    setClaiming(true)
    const { error } = await supabase.rpc('claim_invitation', { p_token: token })
    if (error) {
      setClaiming(false)
      setClaimError(error.message || t.claimError)
      return
    }
    await queryClient.invalidateQueries({ queryKey: ['my-portal'] })
    navigate('/portal', { replace: true })
  }

  if (preview.isLoading) {
    return <Shell><p role="status" className="text-muted">{t.loading}</p></Shell>
  }
  const p = preview.data
  if (preview.error || !p || p.state === 'invalid') {
    return <Shell><Message title={t.invalidTitle} body={t.invalidBody} /></Shell>
  }
  if (p.state === 'revoked') return <Shell><Message title={t.revokedTitle} body={t.revokedBody} /></Shell>
  if (p.state === 'expired') return <Shell><Message title={t.expiredTitle} body={t.expiredBody} /></Shell>
  if (p.state === 'used') {
    return (
      <Shell>
        <Message title={t.usedTitle} body={t.usedBody}>
          <Link to={session ? '/portal' : '/ingreso'} className="btn btn-primary self-start">
            {session ? t.goPortal : t.goLogin}
          </Link>
        </Message>
      </Shell>
    )
  }

  // Invitación vigente
  const sessionEmail = session?.user.email ?? null
  const sameAccount = sessionEmail !== null && emailHint(sessionEmail) === p.email_hint

  return (
    <Shell>
      <h1 className="text-2xl font-extrabold tracking-tight">{t.invitedBy(p.company_name ?? '')}</h1>
      <p className="mt-2 text-sm text-muted">
        {t.contractor}: <span className="font-bold text-ink">{p.contractor_name}</span>
      </p>

      <div className="mt-6">
        {claiming ? (
          <p role="status" className="text-muted">{t.claiming}</p>
        ) : sessionEmail ? (
          <div className="flex flex-col gap-4">
            <p>{t.sessionAs(sessionEmail)}</p>
            {sameAccount ? (
              <button type="button" onClick={claim} className="btn btn-primary">{t.continueAs}</button>
            ) : (
              <>
                <p className="text-sm text-muted">{t.otherAccount(p.email_hint ?? '')}</p>
                <button type="button" onClick={() => signOut()} className="btn btn-secondary">{t.signOutContinue}</button>
              </>
            )}
          </div>
        ) : (
          <div className="flex flex-col gap-4">
            <p className="text-muted">{t.intro}</p>
            <OtpForm shouldCreateUser emailHint={p.email_hint} onVerified={claim} />
          </div>
        )}
        <div aria-live="polite">
          {claimError && (
            <p role="alert" className="mt-4 rounded-xl bg-danger-bg px-3 py-2 text-sm font-bold text-danger">
              {claimError}
            </p>
          )}
        </div>
        {claimError && sessionEmail && (
          <button type="button" onClick={() => signOut()} className="btn btn-secondary mt-3">{t.signOutContinue}</button>
        )}
      </div>
    </Shell>
  )
}
