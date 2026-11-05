import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { es } from '../../i18n/es'
import { useAuth } from './AuthProvider'

export function RequireAuth() {
  const { session, loading } = useAuth()
  const location = useLocation()

  if (loading) {
    return (
      <p role="status" className="p-8 text-muted">
        {es.loading}
      </p>
    )
  }
  if (!session) {
    return <Navigate to="/login" replace state={{ from: location }} />
  }
  return <Outlet />
}
