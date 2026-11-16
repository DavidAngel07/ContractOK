import { es } from '../../i18n/es'
import { Notice } from '../../components/Notice'
import type { useSetupSummary } from './useSetupSummary'

type Summary = ReturnType<typeof useSetupSummary>

function Stat({ value, label, note }: { value: number; label: string; note?: string }) {
  return (
    <div className="card p-5">
      <p className="text-3xl leading-none font-extrabold tracking-tight">{value}</p>
      <p className="mt-1 text-sm text-muted">{label}</p>
      {note && <p className="mt-1 text-xs font-bold text-link">{note}</p>}
    </div>
  )
}

export function SetupReview({ summary, onGo }: { summary: Summary; onGo: (step: number) => void }) {
  const t = es.setup.review
  if (summary.isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  const solo = summary.members <= 1 && summary.pending === 0

  return (
    <div className="flex flex-col gap-6">
      <section aria-label={es.setup.steps[5].title} className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Stat value={summary.activeDocs} label={t.documents} />
        <Stat value={summary.activeProfiles} label={t.profiles} />
        <Stat value={summary.roles} label={t.roles} />
        <Stat value={summary.members} label={t.people} note={summary.pending > 0 ? t.pending(summary.pending) : undefined} />
      </section>

      <section className="card p-6" aria-labelledby="check-title">
        <h3 id="check-title" className="text-lg font-bold">{t.checklist}</h3>
        <ul className="mt-3 flex flex-col gap-3">
          {summary.activeDocs > 0 && <li><Notice kind="ok">{t.okDocuments(summary.activeDocs)}</Notice></li>}
          {summary.profilesWithItems > 0 && <li><Notice kind="ok">{t.okProfiles(summary.profilesWithItems)}</Notice></li>}
          {summary.blockers.map((b) => (
            <li key={b.text} className="flex flex-wrap items-center justify-between gap-3">
              <Notice kind="error">{b.text}</Notice>
              <button type="button" className="btn btn-secondary btn-sm" onClick={() => onGo(b.step)}>{t.goStep} {b.step}</button>
            </li>
          ))}
          {summary.emptyProfiles.length > 0 && (
            <li className="flex flex-wrap items-center justify-between gap-3">
              <Notice kind="info">{t.emptyProfiles(summary.emptyProfiles.map((p) => p.name).join(', '))}</Notice>
              <button type="button" className="btn btn-secondary btn-sm" onClick={() => onGo(3)}>{t.goStep} 3</button>
            </li>
          )}
          {solo && <li><Notice kind="info">{t.soloTeam}</Notice></li>}
        </ul>
        <p className="mt-4 font-bold" role="status">{summary.blockers.length === 0 ? t.ready : t.blocked}</p>
      </section>
    </div>
  )
}
