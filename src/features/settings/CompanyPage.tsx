import { useEffect, useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { Notice } from '../../components/Notice'
import { useAccount } from '../account/useAccount'

type CompanyRow = {
  id: string
  name: string
  nit: string | null
  address: string | null
  city: string | null
  country: string
  contact_email: string | null
  contact_phone: string | null
  timezone: string
}
type SettingsRow = {
  alert_days: number[]
  monthly_period_open_day: number
  invitation_valid_days: number
  reminder_after_days: number
}

const TIMEZONES = [
  'America/Bogota', 'America/Mexico_City', 'America/Lima', 'America/Santiago', 'America/Argentina/Buenos_Aires',
  'America/Guayaquil', 'America/Caracas', 'America/Panama', 'America/New_York', 'Europe/Madrid',
]

export function parseAlertDays(text: string): number[] | null {
  const parts = text.split(',').map((p) => p.trim()).filter(Boolean)
  if (parts.length === 0) return null
  const nums = parts.map((p) => (/^\d+$/.test(p) ? Number(p) : NaN))
  if (nums.some((n) => Number.isNaN(n) || n < 0 || n > 365)) return null
  return [...new Set(nums)].sort((a, b) => b - a)
}

const inRange = (v: string, min: number, max: number) => /^\d+$/.test(v.trim()) && Number(v) >= min && Number(v) <= max

export function CompanyPage({ submitLabel, onSaved }: { submitLabel?: string; onSaved?: () => void } = {}) {
  const { account } = useAccount()
  const queryClient = useQueryClient()
  const t = es.settings.company
  const companyId = account?.companyId

  const [form, setForm] = useState({ name: '', nit: '', address: '', city: '', country: 'CO', contact_email: '', contact_phone: '', timezone: 'America/Bogota' })
  const [cfg, setCfg] = useState({ alertDays: '30, 15, 7, 0', periodDay: '1', inviteDays: '7', reminderDays: '3' })
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [message, setMessage] = useState<{ kind: 'ok' | 'error'; text: string } | null>(null)

  const company = useQuery({
    queryKey: ['company', companyId],
    enabled: Boolean(companyId),
    queryFn: async () => {
      const [c, s] = await Promise.all([
        supabase.from('companies').select('id, name, nit, address, city, country, contact_email, contact_phone, timezone').eq('id', companyId!).maybeSingle(),
        supabase.from('company_settings').select('alert_days, monthly_period_open_day, invitation_valid_days, reminder_after_days').eq('company_id', companyId!).maybeSingle(),
      ])
      if (c.error) throw c.error
      if (s.error) throw s.error
      return { company: c.data as CompanyRow | null, settings: s.data as SettingsRow | null }
    },
  })

  useEffect(() => {
    const c = company.data?.company
    const s = company.data?.settings
    if (c) setForm({ name: c.name, nit: c.nit ?? '', address: c.address ?? '', city: c.city ?? '', country: c.country, contact_email: c.contact_email ?? '', contact_phone: c.contact_phone ?? '', timezone: c.timezone })
    if (s) setCfg({ alertDays: s.alert_days.join(', '), periodDay: String(s.monthly_period_open_day), inviteDays: String(s.invitation_valid_days), reminderDays: String(s.reminder_after_days) })
  }, [company.data])

  const save = useMutation({
    mutationFn: async () => {
      const days = parseAlertDays(cfg.alertDays)!
      const r1 = await supabase.from('companies').update({
        name: form.name.trim(),
        nit: form.nit.trim() || null,
        address: form.address.trim() || null,
        city: form.city.trim() || null,
        country: form.country.trim().toUpperCase() || 'CO',
        contact_email: form.contact_email.trim() || null,
        contact_phone: form.contact_phone.trim() || null,
        timezone: form.timezone,
      }).eq('id', companyId!)
      if (r1.error) throw r1.error
      const r2 = await supabase.from('company_settings').update({
        alert_days: days,
        monthly_period_open_day: Number(cfg.periodDay),
        invitation_valid_days: Number(cfg.inviteDays),
        reminder_after_days: Number(cfg.reminderDays),
      }).eq('company_id', companyId!)
      if (r2.error) throw r2.error
    },
    onSuccess: async () => {
      setMessage({ kind: 'ok', text: es.settings.saved })
      await queryClient.invalidateQueries({ queryKey: ['company', companyId] })
      await queryClient.invalidateQueries({ queryKey: ['account-context'] })
      onSaved?.()
    },
    onError: () => setMessage({ kind: 'error', text: es.settings.saveError }),
  })

  function onSubmit(event: FormEvent) {
    event.preventDefault()
    setMessage(null)
    const next: Record<string, string> = {}
    if (!form.name.trim()) next.name = es.settings.required
    if (!parseAlertDays(cfg.alertDays)) next.alertDays = t.alertDaysInvalid
    if (!inRange(cfg.periodDay, 1, 28)) next.periodDay = t.numberRange(1, 28)
    if (!inRange(cfg.inviteDays, 1, 60)) next.inviteDays = t.numberRange(1, 60)
    if (!inRange(cfg.reminderDays, 1, 30)) next.reminderDays = t.numberRange(1, 30)
    if (form.country.trim().length > 0 && form.country.trim().length !== 2) next.country = t.country
    setErrors(next)
    if (Object.keys(next).length === 0) save.mutate()
  }

  if (company.isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  if (company.error || !company.data?.company) return <Notice kind="error">{es.common.loadError}</Notice>

  const text = (id: keyof typeof form, label: string, props: { type?: string; max?: number } = {}) => (
    <div>
      <label htmlFor={`c-${id}`} className="mb-1.5 block text-sm font-bold">{label}</label>
      <input id={`c-${id}`} type={props.type ?? 'text'} maxLength={props.max} value={form[id]} onChange={(e) => setForm({ ...form, [id]: e.target.value })}
        aria-invalid={Boolean(errors[id])} aria-describedby={errors[id] ? `c-${id}-err` : undefined} className="field" />
      {errors[id] && <p id={`c-${id}-err`} className="mt-1 text-sm font-bold text-danger">{errors[id]}</p>}
    </div>
  )
  const num = (id: keyof typeof cfg, label: string, help?: string) => (
    <div>
      <label htmlFor={`s-${id}`} className="mb-1.5 block text-sm font-bold">{label}</label>
      <input id={`s-${id}`} value={cfg[id]} onChange={(e) => setCfg({ ...cfg, [id]: e.target.value })}
        aria-invalid={Boolean(errors[id])} aria-describedby={`s-${id}-d`} className="field" />
      <p id={`s-${id}-d`} className={`mt-1 text-sm ${errors[id] ? 'font-bold text-danger' : 'text-muted'}`}>{errors[id] ?? help}</p>
    </div>
  )

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-6">
      <section className="card flex flex-col gap-4 p-6" aria-labelledby="co-title">
        <h2 id="co-title" className="text-xl font-bold">{t.title}</h2>
        {text('name', t.name)}
        <div className="grid gap-4 sm:grid-cols-2">
          {text('nit', t.nit)}
          {text('city', t.city)}
        </div>
        {text('address', t.address)}
        <div className="grid gap-4 sm:grid-cols-2">
          {text('contact_email', t.contactEmail, { type: 'email' })}
          {text('contact_phone', t.contactPhone, { type: 'tel' })}
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          {text('country', t.country, { max: 2 })}
          <div>
            <label htmlFor="c-timezone" className="mb-1.5 block text-sm font-bold">{t.timezone}</label>
            <select id="c-timezone" value={form.timezone} onChange={(e) => setForm({ ...form, timezone: e.target.value })} className="field">
              {TIMEZONES.map((z) => <option key={z} value={z}>{z}</option>)}
            </select>
          </div>
        </div>
      </section>

      <section className="card flex flex-col gap-4 p-6" aria-labelledby="st-title">
        <h2 id="st-title" className="text-xl font-bold">{t.alertsTitle}</h2>
        {num('alertDays', t.alertDays, t.alertDaysHelp)}
        <div className="grid gap-4 sm:grid-cols-3">
          {num('periodDay', t.periodDay, t.periodDayHelp)}
          {num('inviteDays', t.inviteDays)}
          {num('reminderDays', t.reminderDays)}
        </div>
      </section>

      <div aria-live="polite">{message && <Notice kind={message.kind}>{message.text}</Notice>}</div>
      <div>
        <button type="submit" disabled={save.isPending} className="btn btn-primary">
          {save.isPending ? es.settings.saving : (submitLabel ?? es.settings.save)}
        </button>
      </div>
    </form>
  )
}
