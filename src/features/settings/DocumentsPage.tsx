import { Link } from 'react-router-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { Notice } from '../../components/Notice'
import { StatusPill } from '../../components/StatusPill'
import { withReturn } from '../../lib/returnTo'
import { PHASES, useDocumentTypes, type DocType } from './hooks'

export function DocumentsPage({ returnTo }: { returnTo?: string } = {}) {
  const { data, isLoading, error } = useDocumentTypes()
  const queryClient = useQueryClient()
  const t = es.settings.docs

  const toggle = useMutation({
    mutationFn: async (doc: DocType) => {
      const { error } = await supabase.from('document_types').update({ is_active: !doc.is_active }).eq('id', doc.id)
      if (error) throw error
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['document-types'] }),
  })

  if (isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  if (error) return <Notice kind="error">{es.common.loadError}</Notice>
  const docs = data ?? []

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold">{t.title}</h2>
          <p className="text-muted">{t.intro}</p>
        </div>
        <Link to={withReturn('/settings/documents/new', returnTo)} className="btn btn-primary">{t.newDoc}</Link>
      </div>
      {toggle.isError && <Notice kind="error">{es.settings.saveError}</Notice>}

      {PHASES.map((phase) => {
        const rows = docs.filter((d) => d.phase === phase)
        return (
          <section key={phase} className="card overflow-hidden" aria-labelledby={`ph-${phase}`}>
            <h3 id={`ph-${phase}`} className="border-b border-line bg-gray-soft px-5 py-3 font-bold">
              {es.settings.phase[phase]}
            </h3>
            {rows.length === 0 ? (
              <p className="px-5 py-4 text-muted">{t.empty}</p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full min-w-170 text-left text-sm">
                  <thead className="text-muted">
                    <tr>
                      <th scope="col" className="px-5 py-2 font-bold">{t.columns.name}</th>
                      <th scope="col" className="px-3 py-2 font-bold">{t.columns.owner}</th>
                      <th scope="col" className="px-3 py-2 font-bold">{t.columns.periodicity}</th>
                      <th scope="col" className="px-3 py-2 font-bold">{t.columns.category}</th>
                      <th scope="col" className="px-3 py-2 font-bold">{t.columns.status}</th>
                      <th scope="col" className="px-5 py-2"><span className="sr-only">{es.contractors.detail.invActions}</span></th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-line">
                    {rows.map((d) => (
                      <tr key={d.id} className={d.is_active ? '' : 'opacity-70'}>
                        <th scope="row" className="px-5 py-3 font-bold">
                          <Link to={withReturn(`/settings/documents/${d.id}`, returnTo)} className="text-link underline">{d.name}</Link>
                        </th>
                        <td className="px-3 py-3">{d.owner_kind === 'worker' ? 'Trabajador' : 'Contratista'}</td>
                        <td className="px-3 py-3">{es.settings.periodicity[d.periodicity]}</td>
                        <td className="px-3 py-3">
                          <StatusPill tone={d.alert_category === 'operational' ? 'info' : 'warn'}>
                            {d.alert_category === 'operational' ? 'Operativo' : 'Cumplimiento'}
                          </StatusPill>
                        </td>
                        <td className="px-3 py-3">
                          <StatusPill tone={d.is_active ? 'ok' : 'neutral'}>{d.is_active ? es.settings.active : es.settings.inactive}</StatusPill>
                        </td>
                        <td className="px-5 py-3 text-right">
                          <button type="button" className="btn btn-secondary btn-sm" disabled={toggle.isPending} onClick={() => toggle.mutate(d)}>
                            {d.is_active ? t.deactivate : t.activate}
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        )
      })}
    </div>
  )
}
