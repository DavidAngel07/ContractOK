import { Outlet } from 'react-router-dom'
import { es } from '../../i18n/es'
import { Logo } from '../../components/Logo'
import { useAuth } from '../auth/AuthProvider'

export function PortalLayout() {
  const { session, signOut } = useAuth()
  return (
    <div className="min-h-screen">
      <a
        href="#contenido"
        className="absolute -top-20 left-4 z-50 rounded-full bg-accent px-4 py-2 font-bold text-accent-ink focus:top-4"
      >
        {es.skipToContent}
      </a>
      <header className="border-b border-line bg-surface">
        <div className="mx-auto flex max-w-4xl flex-wrap items-center justify-between gap-3 px-6 py-3">
          <Logo />
          <div className="flex items-center gap-3">
            <span className="hidden max-w-56 truncate text-sm text-muted sm:inline">{session?.user.email}</span>
            <button type="button" onClick={() => signOut()} className="btn btn-secondary btn-sm">
              {es.layout.signOut}
            </button>
          </div>
        </div>
      </header>
      <main id="contenido" className="mx-auto max-w-4xl px-6 py-8">
        <Outlet />
      </main>
    </div>
  )
}
