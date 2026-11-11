import { Navigate, Outlet } from 'react-router-dom'
import { es } from '../../i18n/es'
import { Logo } from '../../components/Logo'
import { useAccount } from '../account/useAccount'
import { useMyPortal } from '../portal/useMyPortal'
import { useAuth } from './AuthProvider'

function Loading() {
  return (
    <p role="status" className="p-8 text-muted">
      {es.loading}
    </p>
  )
}

// Decide a dónde va cada persona al entrar: personal de la empresa o contratista.
export function EntryRedirect() {
  const { account, isLoading } = useAccount()
  const portal = useMyPortal()
  const { signOut } = useAuth()

  if (isLoading || portal.isLoading) return <Loading />
  if (account) return <Navigate to="/dashboard" replace />
  if ((portal.data ?? []).length > 0) return <Navigate to="/portal" replace />

  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <div className="w-full max-w-lg">
        <div className="mb-8">
          <Logo />
        </div>
        <div className="card p-8">
          <h1 className="text-2xl font-extrabold tracking-tight">{es.noAccess.title}</h1>
          <p className="mt-2 text-muted">{es.noAccess.body}</p>
          <button type="button" onClick={() => signOut()} className="btn btn-secondary mt-6">
            {es.layout.signOut}
          </button>
        </div>
      </div>
    </main>
  )
}

export function RequireStaff() {
  const { account, isLoading } = useAccount()
  if (isLoading) return <Loading />
  if (!account) return <Navigate to="/" replace />
  return <Outlet />
}

export function RequireContractor() {
  const portal = useMyPortal()
  if (portal.isLoading) return <Loading />
  if ((portal.data ?? []).length === 0) return <Navigate to="/" replace />
  return <Outlet />
}
