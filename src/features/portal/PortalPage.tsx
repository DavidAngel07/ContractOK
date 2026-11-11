import { Navigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { StatusPill } from '../../components/StatusPill'
import { contractorStatusTone } from '../contractors/utils'
import { ProfileForm } from './ProfileForm'
import { WorkersSection } from './WorkersSection'
import { profileComplete } from './progress'
import { useMyPortal, type PortalRow } from './useMyPortal'

function Step({ label, state }: { label: string; state: 'done' | 'pending' | 'soon' }) {
  const t = es.portal
  const text = state === 'done' ? t.done : state === 'soon' ? t.soon : t.pending
  const tone = state === 'done' ? 'ok' : state === 'soon' ? 'neutral' : 'warn'
  return (
    <li className="flex flex-wrap items-center justify-between gap-2 py-2.5">
      <span className="font-semibold">{label}</span>
      <span className={`pill pill-${tone}`}>{text}</span>
    </li>
  )
}

function ContractorCard({ row }: { row: PortalRow }) {
  const t = es.portal
  const isCompany = row.kind === 'company'

  // Misma consulta que el formulario de datos (comparten caché) para calcular el avance.
  const profile = useQuery({
    queryKey: ['portal-contractor', row.contractor_id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('contractors')
        .select('id, display_name, legal_name, tax_id, phone, email, status')
        .eq('id', row.contractor_id)
        .maybeSingle()
      if (error) throw error
      return data
    },
  })
  const workers = useQuery({
    queryKey: ['portal-workers', row.contractor_id],
    enabled: isCompany,
    queryFn: async () => {
      const { data, error } = await supabase.from('workers').select('id, full_name, id_number, job_title').eq('contractor_id', row.contractor_id)
      if (error) throw error
      return data ?? []
    },
  })

  return (
    <div className="flex flex-col gap-6">
      <div>
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="text-3xl font-extrabold tracking-tight">{t.greeting(row.display_name)}</h1>
          <StatusPill tone={contractorStatusTone[row.status] ?? 'neutral'}>
            {es.contractors.status[row.status as keyof typeof es.contractors.status] ?? row.status}
          </StatusPill>
        </div>
        <p className="mt-1 text-muted">{t.invitedBy(row.company_name)}</p>
      </div>

      <section className="card p-6" aria-labelledby="steps-title">
        <h2 id="steps-title" className="text-xl font-bold">{t.stepsTitle}</h2>
        <ul className="mt-2 flex flex-col divide-y divide-line">
          <Step label={t.stepProfile} state={profileComplete(profile.data) ? 'done' : 'pending'} />
          {isCompany && <Step label={t.stepWorkers} state={(workers.data ?? []).length > 0 ? 'done' : 'pending'} />}
          <Step label={t.stepDocs} state="soon" />
        </ul>
      </section>

      <section className="card p-6" aria-labelledby="profile-title">
        <h2 id="profile-title" className="text-xl font-bold">{t.profileTitle}</h2>
        <ProfileForm contractorId={row.contractor_id} />
      </section>

      {isCompany && (
        <section className="card p-6" aria-labelledby="workers-title">
          <h2 id="workers-title" className="text-xl font-bold">{t.workersTitle}</h2>
          <WorkersSection contractorId={row.contractor_id} companyId={row.company_id} />
        </section>
      )}

      <section className="card p-6" aria-labelledby="docs-title">
        <h2 id="docs-title" className="text-xl font-bold">{t.docsTitle}</h2>
        <p className="mt-1 text-muted">{t.docsBody}</p>
      </section>
    </div>
  )
}

export function PortalPage() {
  const portal = useMyPortal()
  if (portal.isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  if (portal.error) return <p role="alert" className="rounded-xl bg-danger-bg px-4 py-3 font-bold text-danger">{es.common.loadError}</p>
  const rows = portal.data ?? []
  if (rows.length === 0) return <Navigate to="/" replace />
  return (
    <div className="flex flex-col gap-12">
      {rows.map((r) => (
        <ContractorCard key={r.contractor_id} row={r} />
      ))}
    </div>
  )
}
