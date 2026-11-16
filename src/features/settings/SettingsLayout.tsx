import { NavLink, Navigate, Outlet } from 'react-router-dom'
import { es } from '../../i18n/es'
import { useAccount } from '../account/useAccount'

const tabClass = ({ isActive }: { isActive: boolean }) =>
  `inline-flex min-h-11 items-center whitespace-nowrap rounded-full px-4 text-sm font-bold ${
    isActive ? 'bg-accent text-accent-ink' : 'text-muted hover:bg-accent-wash'
  }`

export function SettingsLayout() {
  const { can } = useAccount()
  const t = es.settings.nav
  return (
    <div className="flex flex-col gap-6">
      <h1 className="text-3xl font-extrabold tracking-tight">{t.title}</h1>
      <nav aria-label={t.menuLabel} className="-mx-1 overflow-x-auto px-1">
        <ul className="flex gap-2">
          {can('company.configure') && (
            <>
              <li><NavLink to="/settings/company" className={tabClass}>{t.company}</NavLink></li>
              <li><NavLink to="/settings/documents" className={tabClass}>{t.documents}</NavLink></li>
              <li><NavLink to="/settings/profiles" className={tabClass}>{t.profiles}</NavLink></li>
            </>
          )}
          {can('users.manage') && (
            <>
              <li><NavLink to="/settings/roles" className={tabClass}>{t.roles}</NavLink></li>
              <li><NavLink to="/settings/users" className={tabClass}>{t.users}</NavLink></li>
            </>
          )}
        </ul>
      </nav>
      <Outlet />
    </div>
  )
}

export function SettingsIndex() {
  const { can, isLoading } = useAccount()
  if (isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  if (can('company.configure')) return <Navigate to="/settings/company" replace />
  if (can('users.manage')) return <Navigate to="/settings/users" replace />
  return <p className="text-muted">{es.settings.noPermission}</p>
}
