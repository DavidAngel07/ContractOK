import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { one } from '../../lib/utils'
import { useAuth } from '../auth/AuthProvider'

type RolePermission = { permission_key: string; scope: 'all' | 'assigned' }
type MembershipRow = {
  id: string
  status: string
  company: { id: string; name: string } | { id: string; name: string }[] | null
  role:
    | { id: string; name: string; description: string | null; role_permissions: RolePermission[] }
    | { id: string; name: string; description: string | null; role_permissions: RolePermission[] }[]
    | null
}

export function HomePage() {
  const { session } = useAuth()
  const userId = session!.user.id

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
      <p role="alert" className="rounded-lg bg-danger-bg px-4 py-3 font-bold text-danger">
        {es.home.loadError}
      </p>
    )
  }

  const name = data.fullName || session!.user.email || ''

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-3xl font-extrabold tracking-tight">{es.home.greeting(name)}</h1>
        <p className="mt-1 text-muted">{es.home.title}</p>
      </div>

      {data.memberships.length === 0 && (
        <p className="rounded-xl border border-line bg-surface p-6">{es.home.noCompany}</p>
      )}

      {data.memberships.map((m) => {
        const company = one(m.company)
        const role = one(m.role)
        const permissions = role?.role_permissions ?? []
        return (
          <section key={m.id} className="rounded-2xl border border-line bg-surface p-6" aria-labelledby={`m-${m.id}`}>
            <h2 id={`m-${m.id}`} className="text-xl font-bold">
              {es.home.companySection}
            </h2>
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
                    <span className="rounded-full border border-line px-3 py-0.5 text-xs font-bold text-muted">
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
