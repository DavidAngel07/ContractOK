import { Link } from 'react-router-dom'
import { es } from '../../i18n/es'
import { Notice } from '../../components/Notice'
import { StatusPill } from '../../components/StatusPill'
import { withReturn } from '../../lib/returnTo'
import { useProfiles } from './hooks'

export function ProfilesPage({ returnTo }: { returnTo?: string } = {}) {
  const { data, isLoading, error } = useProfiles()
  const t = es.settings.profiles
  if (isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  if (error) return <Notice kind="error">{es.common.loadError}</Notice>
  const rows = data ?? []

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold">{t.title}</h2>
          <p className="text-muted">{t.intro}</p>
        </div>
        <Link to={withReturn('/settings/profiles/new', returnTo)} className="btn btn-primary">{t.newProfile}</Link>
      </div>
      {rows.length === 0 ? (
        <p className="card p-6">{t.empty}</p>
      ) : (
        <div className="card overflow-x-auto">
          <table className="w-full min-w-150 text-left text-sm">
            <thead className="border-b border-line bg-gray-soft text-muted">
              <tr>
                <th scope="col" className="px-5 py-3 font-bold">{t.columns.name}</th>
                <th scope="col" className="px-3 py-3 font-bold">{t.columns.kind}</th>
                <th scope="col" className="px-3 py-3 font-bold">{t.columns.items}</th>
                <th scope="col" className="px-3 py-3 font-bold">{t.columns.status}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {rows.map((p) => (
                <tr key={p.id} className={p.is_active ? '' : 'opacity-70'}>
                  <th scope="row" className="px-5 py-3 font-bold">
                    <Link to={withReturn(`/settings/profiles/${p.id}`, returnTo)} className="text-link underline">{p.name}</Link>
                    {p.description && <span className="block text-sm font-normal text-muted">{p.description}</span>}
                  </th>
                  <td className="px-3 py-3">{t.kind[p.contractor_kind]}</td>
                  <td className="px-3 py-3">{p.items?.[0]?.count ?? 0}</td>
                  <td className="px-3 py-3"><StatusPill tone={p.is_active ? 'ok' : 'neutral'}>{p.is_active ? es.settings.active : es.settings.inactive}</StatusPill></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
