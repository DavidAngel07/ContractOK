import { Outlet } from 'react-router-dom'
import { es } from '../../i18n/es'
import { Notice } from '../../components/Notice'
import { useAccount } from '../account/useAccount'

// Muestra las pantallas hijas solo si el rol tiene la responsabilidad indicada.
export function Gate({ permission }: { permission: string }) {
  const { can, isLoading } = useAccount()
  if (isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  if (!can(permission)) return <Notice kind="error">{es.settings.noPermission}</Notice>
  return <Outlet />
}
