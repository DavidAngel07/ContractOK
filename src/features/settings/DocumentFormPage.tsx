import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { safeReturn } from '../../lib/returnTo'
import { Notice } from '../../components/Notice'
import { useAccount } from '../account/useAccount'
import { PHASES, useDocumentTypes, type DbError, type DocType } from './hooks'

type Form = {
  name: string
  description: string
  instructions: string
  owner_kind: DocType['owner_kind']
  scope: DocType['scope']
  phase: DocType['phase']
  periodicity: DocType['periodicity']
  requires_dates: boolean
  max_age_days: string
  retention_years: string
  alert_category: DocType['alert_category']
  alert_audience: string[]
  is_active: boolean
}

const AUDIENCE_DEFAULTS: Record<DocType['alert_category'], string[]> = {
  operational: ['contractor', 'supervisor'],
  compliance: ['contractor', 'reviewer', 'supervisor'],
}

const EMPTY: Form = {
  name: '', description: '', instructions: '', owner_kind: 'contractor', scope: 'contractor', phase: 'contracting',
  periodicity: 'once', requires_dates: false, max_age_days: '', retention_years: '10',
  alert_category: 'compliance', alert_audience: AUDIENCE_DEFAULTS.compliance, is_active: true,
}

// Reglas que la base de datos también exige: se aplican en la pantalla para no dejar combinaciones inválidas.
export function normalizeForm(f: Form): Form {
  return {
    ...f,
    scope: f.owner_kind === 'worker' ? 'contractor' : f.scope,
    phase: f.periodicity === 'monthly' ? 'monthly' : f.periodicity === 'closing' ? 'closing' : f.phase,
    requires_dates: f.periodicity === 'expiring' ? true : f.requires_dates,
  }
}

export function DocumentFormPage() {
  const { id } = useParams()
  const isNew = !id
  const navigate = useNavigate()
  const [search] = useSearchParams()
  const back = safeReturn(search.get('return'), '/settings/documents')
  const queryClient = useQueryClient()
  const { account } = useAccount()
  const docs = useDocumentTypes()
  const t = es.settings.docs
  const [form, setForm] = useState<Form>(EMPTY)
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [message, setMessage] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  const existing = docs.data?.find((d) => d.id === id)
  useEffect(() => {
    if (!existing) return
    setForm({
      name: existing.name, description: existing.description ?? '', instructions: existing.instructions ?? '',
      owner_kind: existing.owner_kind, scope: existing.scope, phase: existing.phase, periodicity: existing.periodicity,
      requires_dates: existing.requires_dates, max_age_days: existing.max_age_days ? String(existing.max_age_days) : '',
      retention_years: String(existing.retention_years), alert_category: existing.alert_category,
      alert_audience: existing.alert_audience, is_active: existing.is_active,
    })
  }, [existing])

  const f = normalizeForm(form)
  const set = <K extends keyof Form>(key: K, value: Form[K]) => setForm((prev) => ({ ...prev, [key]: value }))

  async function submit(event: FormEvent) {
    event.preventDefault()
    setMessage(null)
    const next: Record<string, string> = {}
    if (!f.name.trim()) next.name = es.settings.required
    if (!/^\d+$/.test(f.retention_years) || Number(f.retention_years) < 1 || Number(f.retention_years) > 50) next.retention = t.retentionRange
    if (f.max_age_days.trim() && (!/^\d+$/.test(f.max_age_days) || Number(f.max_age_days) < 1 || Number(f.max_age_days) > 3650)) next.maxAge = t.maxAgeRange
    if (f.alert_audience.length === 0) next.audience = t.audienceRequired
    setErrors(next)
    if (Object.keys(next).length > 0) return

    const payload = {
      name: f.name.trim(), description: f.description.trim() || null, instructions: f.instructions.trim() || null,
      owner_kind: f.owner_kind, scope: f.scope, phase: f.phase, periodicity: f.periodicity, requires_dates: f.requires_dates,
      max_age_days: f.max_age_days.trim() ? Number(f.max_age_days) : null, retention_years: Number(f.retention_years),
      alert_category: f.alert_category, alert_audience: f.alert_audience, is_active: f.is_active,
    }
    setBusy(true)
    const result = isNew
      ? await supabase.from('document_types').insert({ ...payload, company_id: account!.companyId, sort_order: 500 })
      : await supabase.from('document_types').update(payload).eq('id', id!)
    setBusy(false)
    if (result.error) {
      const code = (result.error as DbError).code
      setMessage(code === '23505' ? t.duplicate : code === '23514' ? t.invalid : es.settings.saveError)
      return
    }
    await queryClient.invalidateQueries({ queryKey: ['document-types'] })
    navigate(back)
  }

  async function remove() {
    if (!window.confirm(t.deleteConfirm)) return
    setBusy(true)
    const { error } = await supabase.from('document_types').delete().eq('id', id!)
    setBusy(false)
    if (error) {
      setMessage((error as DbError).code === '23503' ? t.inProfile : es.settings.saveError)
      return
    }
    await queryClient.invalidateQueries({ queryKey: ['document-types'] })
    navigate(back)
  }

  if (!isNew && docs.isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  if (!isNew && !docs.isLoading && !existing) return <Notice kind="error">{es.common.notFound}</Notice>

  const radio = (name: string, value: string, checked: boolean, onChange: () => void, label: string, help?: string) => (
    <label className="flex cursor-pointer items-start gap-3 rounded-xl border border-line p-3 has-checked:border-accent has-checked:bg-accent-wash">
      <input type="radio" name={name} value={value} checked={checked} onChange={onChange} className="mt-1" />
      <span><span className="block font-bold">{label}</span>{help && <span className="text-sm text-muted">{help}</span>}</span>
    </label>
  )

  return (
    <form onSubmit={submit} noValidate className="mx-auto flex max-w-3xl flex-col gap-6">
      <div>
        <Link to={back} className="text-sm font-bold text-link underline">← {t.title}</Link>
        <h2 className="mt-2 text-2xl font-extrabold tracking-tight">{isNew ? t.newTitle : t.editTitle}</h2>
      </div>

      <section className="card flex flex-col gap-4 p-6">
        <div>
          <label htmlFor="d-name" className="mb-1.5 block text-sm font-bold">{t.name}</label>
          <input id="d-name" value={form.name} onChange={(e) => set('name', e.target.value)} aria-invalid={Boolean(errors.name)} className="field" />
          {errors.name && <p className="mt-1 text-sm font-bold text-danger">{errors.name}</p>}
        </div>
        <div>
          <label htmlFor="d-desc" className="mb-1.5 block text-sm font-bold">{t.description}</label>
          <input id="d-desc" value={form.description} onChange={(e) => set('description', e.target.value)} className="field" />
        </div>
        <div>
          <label htmlFor="d-inst" className="mb-1.5 block text-sm font-bold">{t.instructions}</label>
          <textarea id="d-inst" rows={3} value={form.instructions} onChange={(e) => set('instructions', e.target.value)} className="field py-2" />
        </div>
      </section>

      <section className="card flex flex-col gap-5 p-6">
        <fieldset className="flex flex-col gap-2">
          <legend className="mb-1 text-sm font-bold">{t.ownerLegend}</legend>
          {radio('owner', 'contractor', f.owner_kind === 'contractor', () => set('owner_kind', 'contractor'), es.settings.owner.contractor)}
          {radio('owner', 'worker', f.owner_kind === 'worker', () => set('owner_kind', 'worker'), es.settings.owner.worker)}
        </fieldset>

        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label htmlFor="d-scope" className="mb-1.5 block text-sm font-bold">{t.scopeLabel}</label>
            <select id="d-scope" value={f.scope} disabled={f.owner_kind === 'worker'} onChange={(e) => set('scope', e.target.value as Form['scope'])} className="field">
              <option value="contractor">{es.settings.scope.contractor}</option>
              <option value="contract">{es.settings.scope.contract}</option>
            </select>
            {f.owner_kind === 'worker' && <p className="mt-1 text-sm text-muted">{t.workerScopeNote}</p>}
          </div>
          <div>
            <label htmlFor="d-periodicity" className="mb-1.5 block text-sm font-bold">{t.periodicityLabel}</label>
            <select id="d-periodicity" value={f.periodicity} onChange={(e) => set('periodicity', e.target.value as Form['periodicity'])} className="field">
              {(['once', 'expiring', 'monthly', 'closing'] as const).map((p) => <option key={p} value={p}>{es.settings.periodicity[p]}</option>)}
            </select>
          </div>
        </div>

        <div>
          <label htmlFor="d-phase" className="mb-1.5 block text-sm font-bold">{t.phaseLabel}</label>
          <select id="d-phase" value={f.phase} disabled={f.periodicity === 'monthly' || f.periodicity === 'closing'} onChange={(e) => set('phase', e.target.value as Form['phase'])} className="field">
            {PHASES.map((p) => <option key={p} value={p}>{es.settings.phase[p]}</option>)}
          </select>
          {f.periodicity === 'monthly' && <p className="mt-1 text-sm text-muted">{t.periodicityMonthlyNote}</p>}
          {f.periodicity === 'closing' && <p className="mt-1 text-sm text-muted">{t.periodicityClosingNote}</p>}
        </div>

        <div>
          <label className="flex min-h-11 cursor-pointer items-center gap-3 font-bold">
            <input type="checkbox" checked={f.requires_dates} disabled={f.periodicity === 'expiring'} onChange={(e) => set('requires_dates', e.target.checked)} />
            {t.requiresDates}
          </label>
          {f.periodicity === 'expiring' && <p className="text-sm text-muted">{t.requiresDatesNote}</p>}
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label htmlFor="d-maxage" className="mb-1.5 block text-sm font-bold">{t.maxAge}</label>
            <input id="d-maxage" inputMode="numeric" value={form.max_age_days} onChange={(e) => set('max_age_days', e.target.value)} className="field" />
            <p className={`mt-1 text-sm ${errors.maxAge ? 'font-bold text-danger' : 'text-muted'}`}>{errors.maxAge ?? t.maxAgeHelp}</p>
          </div>
          <div>
            <label htmlFor="d-retention" className="mb-1.5 block text-sm font-bold">{t.retention}</label>
            <input id="d-retention" inputMode="numeric" value={form.retention_years} onChange={(e) => set('retention_years', e.target.value)} className="field" />
            <p className={`mt-1 text-sm ${errors.retention ? 'font-bold text-danger' : 'text-muted'}`}>{errors.retention ?? t.retentionHelp}</p>
          </div>
        </div>
      </section>

      <section className="card flex flex-col gap-5 p-6">
        <fieldset className="flex flex-col gap-2">
          <legend className="mb-1 text-sm font-bold">{t.categoryLegend}</legend>
          {radio('cat', 'operational', form.alert_category === 'operational', () => setForm((p) => ({ ...p, alert_category: 'operational', alert_audience: AUDIENCE_DEFAULTS.operational })), es.settings.category.operational)}
          {radio('cat', 'compliance', form.alert_category === 'compliance', () => setForm((p) => ({ ...p, alert_category: 'compliance', alert_audience: AUDIENCE_DEFAULTS.compliance })), es.settings.category.compliance)}
        </fieldset>
        <fieldset>
          <legend className="mb-1 text-sm font-bold">{t.audienceLegend}</legend>
          <div className="flex flex-wrap gap-x-6">
            {(['contractor', 'reviewer', 'supervisor', 'admin'] as const).map((a) => (
              <label key={a} className="flex min-h-11 cursor-pointer items-center gap-2">
                <input type="checkbox" checked={form.alert_audience.includes(a)}
                  onChange={(e) => set('alert_audience', e.target.checked ? [...form.alert_audience, a] : form.alert_audience.filter((x) => x !== a))} />
                {es.settings.audience[a]}
              </label>
            ))}
          </div>
          {errors.audience && <p className="text-sm font-bold text-danger">{errors.audience}</p>}
        </fieldset>
        <label className="flex min-h-11 cursor-pointer items-center gap-3 font-bold">
          <input type="checkbox" checked={form.is_active} onChange={(e) => set('is_active', e.target.checked)} />
          {t.active}
        </label>
      </section>

      <div aria-live="polite">{message && <Notice kind="error">{message}</Notice>}</div>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex gap-3">
          <button type="submit" disabled={busy} className="btn btn-primary">{busy ? es.settings.saving : es.settings.save}</button>
          <Link to={back} className="btn btn-secondary">{es.settings.cancel}</Link>
        </div>
        {!isNew && <button type="button" onClick={remove} disabled={busy} className="btn btn-danger-outline">{es.settings.delete}</button>}
      </div>
    </form>
  )
}
