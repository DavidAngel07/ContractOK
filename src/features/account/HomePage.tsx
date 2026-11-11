import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { one } from '../../lib/utils'
import { AlertIcon, CheckCircleIcon, ClockIcon, UsersIcon } from '../../components/icons'
import { useContractors } from '../contractors/useContractors'
import { useAuth } from '../auth/AuthProvider'
import { useAccount } from './useAccount'

type RolePermission = { permission_key: string; scope: 'all' | 'assigned' }
type Role = { id: string; name: string; description: string | null; role_permissions: RolePermission[] }
type MembershipRow = {
  id: string
  status: string
  company: { id: string; name: string } | { id: string; name: string }[] | null
  role: Role | Role[] | null
}

function Kpi({ icon, value, label }: { icon: ReactNode; value: number; label: string }) {
  return (
    <div className="card flex items-center gap-4 p-5">
      <span className="inline-flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-accent-soft text-ink">
        {icon}
      </span>
      <div>
        <p className="text-3xl leading-none font-extrabold tracking-tight">{value}</p>
        <p className="mt-1 text-sm text-muted">{label}</p>
      </div>
    </div>
  )
}

export function HomePage() {
  const { session } = useAuth()
  const { can } = useAccount()
  const userId = session!.user.id
  const contractors = useContractors()

  const { data, error, isLoading } = useQuery({
    queryKey: ['account', userId],
    queryFn: async () => {
      const [profile, memberships, permissions] = await Promise.all([
        supabase.from('profiles').select('full_name, job_title').eq('id', userId).maybeSingle(),
        supabase
          .from('memberships')
          .select(
            'id, status, company:companies(id, name), role:roles(id, name, description, role_permissions(permission_key, scope))',
          )
          .eq('user_id', userId),
        supabase.from('permissions').select('key, description'),
      ])
      const failure = profile.error ?? memberships.error ?? permissions.error
      if (failure) throw failure
      return {
        fullName: profile.data?.full_name as string | null | undefined,
        memberships: (memberships.data ?? []) as unknown as MembershipRow[],
        descriptions: new Map((permissions.data ?? []).map((p) => [p.key as string, p.description as string])),
      }
    },
  })

  if (isLoading) {
    return (
      <p role="status" className="text-muted">
        {es.loading}
      </p>
    )
  }
  if (error || !data) {
    return (
      <p role="alert" className="rounded-xl bg-danger-bg px-4 py-3 font-bold text-danger">
        {es.home.loadError}
      </p>
    )
  }

  const name = data.fullName || session!.user.email || ''
  const rows = contractors.data ?? []
  const count = (...statuses: string[]) => rows.filter((r) => statuses.includes(r.status)).length
  const hasCompany = data.memberships.length > 0

  return (
    <div className="flex flex-col gap-8">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-3xl font-extrabold tracking-tight">{es.home.greeting(name)}</h1>
          <p className="mt-1 text-muted">{es.home.summary}</p>
        </div>
        {hasCompany && can('contractors.manage') && (
          <Link to="/contractors/new" className="btn btn-primary">
            {es.home.inviteContractor}
          </Link>
        )}
      </div>

      {!hasCompany && <p className="card p-6">{es.home.noCompany}</p>}

      {hasCompany && (
        <section aria-label={es.nav.contractors} className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <Kpi icon={<UsersIcon />} value={rows.length} label={es.home.kpiTotal} />
          <Kpi icon={<CheckCircleIcon />} value={count('enabled', 'active')} label={es.home.kpiEnabled} />
          <Kpi icon={<ClockIcon />} value={count('in_review')} label={es.home.kpiReview} />
          <Kpi icon={<AlertIcon />} value={count('observations')} label={es.home.kpiObservations} />
        </section>
      )}

      {data.memberships.map((m) => {
        const company = one(m.company)
        const role = one(m.role)
        const permissions = role?.role_permissions ?? []
        return (
          <section key={m.id} className="card p-6" aria-labelledby={`m-${m.id}`}>
            <div className="flex flex-wrap items-center justify-between gap-3">
              <h2 id={`m-${m.id}`} className="text-xl font-bold">
                {es.home.companySection}
              </h2>
              <Link to="/contractors" className="btn btn-secondary btn-sm">
                {es.home.viewContractors}
              </Link>
            </div>
            <dl className="mt-4 grid gap-4 sm:grid-cols-2">
              <div>
                <dt className="text-sm text-muted">{es.home.company}</dt>
                <dd className="text-lg font-bold">{company?.name ?? '—'}</dd>
              </div>
              <div>
                <dt className="text-sm text-muted">{es.home.role}</dt>
                <dd className="text-lg font-bold">{role?.name ?? '—'}</dd>
                {role?.description && <dd className="text-sm text-muted">{role.description}</dd>}
              </div>
            </dl>

            <h3 className="mt-6 text-base font-bold">{es.home.responsibilities}</h3>
            {permissions.length === 0 ? (
              <p className="mt-2 text-muted">{es.home.noResponsibilities}</p>
            ) : (
              <ul className="mt-3 flex flex-col divide-y divide-line">
                {permissions.map((p) => (
                  <li key={p.permission_key} className="flex flex-wrap items-center justify-between gap-2 py-2.5">
                    <span>{data.descriptions.get(p.permission_key) ?? p.permission_key}</span>
                    <span className="pill pill-info">
                      {p.scope === 'all' ? es.home.scopeAll : es.home.scopeAssigned}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </section>
        )
      })}
    </div>
  )
}
