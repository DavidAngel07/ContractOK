import { useState } from 'react'
import { NavLink, Outlet } from 'react-router-dom'
import { es } from '../i18n/es'
import { useAuth } from '../features/auth/AuthProvider'
import { HomeIcon, MenuIcon, UsersIcon } from './icons'
import { Logo } from './Logo'

const navClass = ({ isActive }: { isActive: boolean }) =>
  `flex min-h-11 items-center gap-3 rounded-xl px-3 font-semibold ${
    isActive ? 'bg-nav-active text-white' : 'text-sidebar-ink hover:bg-white/10'
  }`

function initials(email: string | undefined) {
  const base = (email ?? '?').split('@')[0].replace(/[^a-zA-Z0-9]/g, ' ').trim()
  const parts = base.split(/\s+/).filter(Boolean)
  const letters = parts.length > 1 ? parts[0][0] + parts[1][0] : base.slice(0, 2)
  return (letters || '?').toUpperCase()
}

export function AppLayout() {
  const { session, signOut } = useAuth()
  const [open, setOpen] = useState(false)
  const email = session?.user.email

  return (
    <div className="min-h-screen md:flex">
      <a
        href="#contenido"
        className="absolute -top-20 left-4 z-50 rounded-full bg-accent px-4 py-2 font-bold text-accent-ink focus:top-4"
      >
        {es.skipToContent}
      </a>

      <aside className="bg-sidebar text-sidebar-ink md:sticky md:top-0 md:flex md:h-screen md:w-64 md:shrink-0 md:flex-col">
        <div className="flex items-center justify-between px-5 py-4">
          <Logo onDark />
          <button
            type="button"
            className="inline-flex min-h-11 min-w-11 items-center justify-center rounded-xl hover:bg-white/10 md:hidden"
            aria-expanded={open}
            aria-controls="menu-principal"
            aria-label={open ? es.nav.closeMenu : es.nav.menu}
            onClick={() => setOpen((v) => !v)}
          >
            <MenuIcon />
          </button>
        </div>

        <nav id="menu-principal" aria-label={es.nav.main} className={`${open ? 'block' : 'hidden'} px-3 pb-4 md:block`}>
          <ul className="flex flex-col gap-1">
            <li>
              <NavLink to="/dashboard" end className={navClass} onClick={() => setOpen(false)}>
                <HomeIcon />
                {es.nav.home}
              </NavLink>
            </li>
            <li>
              <NavLink to="/contractors" className={navClass} onClick={() => setOpen(false)}>
                <UsersIcon />
                {es.nav.contractors}
              </NavLink>
            </li>
          </ul>
        </nav>

        <p className="mt-auto hidden px-5 py-5 text-sm opacity-80 md:block">{es.brand.tagline}</p>
      </aside>

      <div className="min-w-0 flex-1">
        <header className="flex items-center justify-end gap-3 border-b border-line bg-surface px-6 py-3">
          <span
            className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-accent-soft text-sm font-extrabold text-ink"
            aria-hidden="true"
          >
            {initials(email)}
          </span>
          <span className="hidden max-w-56 truncate text-sm text-muted sm:inline">
            {es.layout.signedInAs} {email}
          </span>
          <button type="button" onClick={signOut} className="btn btn-secondary btn-sm">
            {es.layout.signOut}
          </button>
        </header>
        <main id="contenido" className="mx-auto max-w-5xl px-6 py-8">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
