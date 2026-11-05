import { Outlet } from 'react-router-dom'
import { es } from '../i18n/es'
import { useAuth } from '../features/auth/AuthProvider'

export function AppLayout() {
  const { session, signOut } = useAuth()

  return (
    <div className="min-h-screen">
      <a
        href="#contenido"
        className="absolute -top-20 left-4 rounded-lg bg-accent px-4 py-2 font-bold text-accent-ink focus:top-4"
      >
        {es.skipToContent}
      </a>
      <header className="border-b border-line bg-surface">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-3 px-6 py-4">
          <p className="text-xl font-extrabold tracking-tight">
            Contract<span className="text-accent">OK</span>
          </p>
          <div className="flex items-center gap-4">
            <span className="text-sm text-muted">
              {es.layout.signedInAs} {session?.user.email}
            </span>
            <button
              type="button"
              onClick={signOut}
              className="min-h-11 rounded-lg border border-line bg-surface px-4 text-sm font-bold"
            >
              {es.layout.signOut}
            </button>
          </div>
        </div>
      </header>
      <main id="contenido" className="mx-auto max-w-5xl px-6 py-8">
        <Outlet />
      </main>
    </div>
  )
}
