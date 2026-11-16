import { Navigate, Outlet } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { Logo } from '../../components/Logo'
import { useAccount, type Account } from '../account/useAccount'
import { useMyPortal } from '../portal/useMyPortal'
import { useAuth } from './AuthProvider'

// El administrador de una empresa nueva empieza por el asistente de configuración; el resto, por el dashboard.
export function staffDestination(account: Pick<Account, 'setupStatus' | 'permissions'>) {
  return account.setupStatus === 'not_started' && account.permissions.has('company.configure') ? '/setup' : '/dashboard'
}

function Loading() {
  return (
    <p role="status" className="p-8 text-muted">
      {es.loading}
    </p>
  )
}

// Decide a dónde va cada persona al entrar: personal de la empresa o contratista.
export function EntryRedirect() {
  const { account, isLoading, isFetching } = useAccount()
  const portal = useMyPortal()
  const { session, signOut } = useAuth()
  const queryClient = useQueryClient()

  // Si no es personal ni contratista, puede tener una invitación de personal pendiente: se activa al ingresar.
  const noRoles = !isLoading && !portal.isLoading && !account && (portal.data ?? []).length === 0
  const claim = useQuery({
    queryKey: ['claim-staff', session?.user.id],
    enabled: noRoles,
    staleTime: Infinity,
    retry: false,
    queryFn: async () => {
      const { data, error } = await supabase.rpc('claim_staff_invitation')
      if (error) throw error
      const n = Number(data ?? 0)
      if (n > 0) await queryClient.invalidateQueries({ queryKey: ['account-context'] })
      return n
    },
  })

  if (isLoading || portal.isLoading || (noRoles && claim.isLoading)) return <Loading />
  if ((claim.data ?? 0) > 0 && !account && isFetching) return <Loading />
  if (account) return <Navigate to={staffDestination(account)} replace />
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
