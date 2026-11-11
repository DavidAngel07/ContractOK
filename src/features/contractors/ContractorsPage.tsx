import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { es } from '../../i18n/es'
import { formatDate } from '../../lib/utils'
import { StatusPill } from '../../components/StatusPill'
import { useAccount } from '../account/useAccount'
import { contractorStatusTone } from './utils'
import { useContractors } from './useContractors'

export function ContractorsPage() {
  const { can } = useAccount()
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState('')
  const t = es.contractors

  const { data, isLoading, error } = useContractors()

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase()
    return (data ?? []).filter(
      (r) =>
        (!status || r.status === status) &&
        (!q || r.display_name.toLowerCase().includes(q) || r.email.toLowerCase().includes(q)),
    )
  }, [data, search, status])

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-3xl font-extrabold tracking-tight">{t.title}</h1>
        {can('contractors.manage') && (
          <Link
            to="/contractors/new"
            className="btn btn-primary"
          >
            {t.invite}
          </Link>
        )}
      </div>

      <div className="flex flex-wrap gap-3">
        <div className="min-w-60 flex-1">
          <label htmlFor="search" className="mb-1.5 block text-sm font-bold">
            {t.search}
          </label>
          <input
            id="search"
            type="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="field"
          />
        </div>
        <div>
          <label htmlFor="status" className="mb-1.5 block text-sm font-bold">
            {t.statusFilter}
          </label>
          <select
            id="status"
            value={status}
            onChange={(e) => setStatus(e.target.value)}
            className="field field-auto"
          >
            <option value="">{t.allStatuses}</option>
            {Object.entries(t.status).map(([key, label]) => (
              <option key={key} value={key}>
                {label}
              </option>
            ))}
          </select>
        </div>
      </div>

      {isLoading && (
        <p role="status" className="text-muted">
          {es.loading}
        </p>
      )}
      {error && (
        <p role="alert" className="rounded-xl bg-danger-bg px-4 py-3 font-bold text-danger">
          {es.common.loadError}
        </p>
      )}
      {!isLoading && !error && rows.length === 0 && (
        <p className="card p-6">
          {(data ?? []).length === 0 ? t.empty : t.emptyFiltered}
        </p>
      )}

      {rows.length > 0 && (
        <div className="card overflow-x-auto">
          <table className="w-full min-w-170 text-left text-sm">
            <thead className="border-b border-line bg-gray-soft text-muted">
              <tr>
                <th scope="col" className="px-4 py-3 font-bold">{t.columns.name}</th>
                <th scope="col" className="px-4 py-3 font-bold">{t.columns.kind}</th>
                <th scope="col" className="px-4 py-3 font-bold">{t.columns.status}</th>
                <th scope="col" className="px-4 py-3 font-bold">{t.columns.email}</th>
                <th scope="col" className="px-4 py-3 font-bold">{t.columns.created}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {rows.map((r) => (
                <tr key={r.id}>
                  <th scope="row" className="px-4 py-3 font-bold">
                    <Link to={`/contractors/${r.id}`} className="text-link underline">
                      {r.display_name}
                    </Link>
                  </th>
                  <td className="px-4 py-3">{t.kind[r.kind]}</td>
                  <td className="px-4 py-3">
                    <StatusPill tone={contractorStatusTone[r.status] ?? 'neutral'}>
                      {t.status[r.status as keyof typeof t.status] ?? r.status}
                    </StatusPill>
                  </td>
                  <td className="px-4 py-3">{r.email}</td>
                  <td className="px-4 py-3">{formatDate(r.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
