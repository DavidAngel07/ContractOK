import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { useAccount } from '../account/useAccount'
import { InviteResult } from './InviteResult'
import { isValidEmail } from './utils'

type Kind = 'natural' | 'company'
type Created = { id: string; token: string; expiresAt: string; name: string; email: string; phone: string | null }

export function NewContractorPage() {
  const { account, can, isLoading } = useAccount()
  const queryClient = useQueryClient()
  const [kind, setKind] = useState<Kind>('natural')
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [errors, setErrors] = useState<{ name?: string; email?: string; form?: string }>({})
  const [submitting, setSubmitting] = useState(false)
  const [created, setCreated] = useState<Created | null>(null)
  const [partialId, setPartialId] = useState<string | null>(null)
  const t = es.contractors.form

  if (isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  if (!account || !can('contractors.manage')) {
    return <p role="alert" className="rounded-lg bg-danger-bg px-4 py-3 font-bold text-danger">{es.common.noPermission}</p>
  }

  if (created) {
    return (
      <div className="flex flex-col gap-4">
        <h1 className="text-3xl font-extrabold tracking-tight">{es.contractors.result.created}</h1>
        <InviteResult
          token={created.token}
          expiresAt={created.expiresAt}
          contractorName={created.name}
          contractorEmail={created.email}
          contractorPhone={created.phone}
          companyName={account.companyName}
          title={es.contractors.result.linkLabel}
        />
        <div className="flex flex-wrap gap-3">
          <Link to={`/contractors/${created.id}`} className="inline-flex min-h-11 items-center rounded-lg bg-accent px-5 font-bold text-accent-ink">
            {es.contractors.result.toDetail}
          </Link>
          <Link to="/contractors" className="inline-flex min-h-11 items-center rounded-lg border border-line px-5 font-bold">
            {es.contractors.result.toList}
          </Link>
        </div>
      </div>
    )
  }

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    const next: typeof errors = {}
    if (!name.trim()) next.name = t.nameRequired
    if (!isValidEmail(email)) next.email = t.emailInvalid
    setErrors(next)
    if (next.name || next.email) return

    setSubmitting(true)
    const cleanEmail = email.trim().toLowerCase()
    const { data: row, error } = await supabase
      .from('contractors')
      .insert({
        company_id: account!.companyId,
        kind,
        display_name: name.trim(),
        email: cleanEmail,
        phone: phone.trim() || null,
      })
      .select('id')
      .single()

    if (error || !row) {
      setSubmitting(false)
      setErrors({ form: error?.code === '23505' ? t.duplicate : t.generic })
      return
    }
    await queryClient.invalidateQueries({ queryKey: ['contractors'] })

    const { data: inv, error: invError } = await supabase.rpc('create_invitation', { p_contractor_id: row.id })
    setSubmitting(false)
    if (invError || !inv) {
      setPartialId(row.id)
      setErrors({ form: t.inviteFailed })
      return
    }
    setCreated({ id: row.id, token: inv.token, expiresAt: inv.expires_at, name: name.trim(), email: cleanEmail, phone: phone.trim() || null })
  }

  const field = 'min-h-11 w-full rounded-lg border border-line bg-bg px-3 text-base'

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-6">
      <div>
        <h1 className="text-3xl font-extrabold tracking-tight">{t.title}</h1>
        <p className="mt-1 text-muted">{t.intro}</p>
      </div>

      <form onSubmit={handleSubmit} noValidate className="flex flex-col gap-5 rounded-2xl border border-line bg-surface p-6">
        <fieldset className="flex flex-col gap-3">
          <legend className="mb-2 text-sm font-bold">{t.kindLegend}</legend>
          {(['natural', 'company'] as const).map((k) => (
            <label key={k} className="flex cursor-pointer items-start gap-3 rounded-xl border border-line p-4 has-checked:border-accent has-checked:bg-bg">
              <input type="radio" name="kind" value={k} checked={kind === k} onChange={() => setKind(k)} className="mt-1" />
              <span>
                <span className="block font-bold">{es.contractors.kind[k]}</span>
                <span className="text-sm text-muted">{k === 'natural' ? t.naturalHelp : t.companyHelp}</span>
              </span>
            </label>
          ))}
        </fieldset>

        <div>
          <label htmlFor="name" className="mb-1.5 block text-sm font-bold">{t.name}</label>
          <input id="name" value={name} onChange={(e) => setName(e.target.value)} aria-invalid={Boolean(errors.name)} aria-describedby={errors.name ? 'name-err' : undefined} className={field} />
          {errors.name && <p id="name-err" className="mt-1 text-sm font-bold text-danger">{errors.name}</p>}
        </div>
        <div>
          <label htmlFor="email" className="mb-1.5 block text-sm font-bold">{t.email}</label>
          <input id="email" type="email" autoComplete="off" value={email} onChange={(e) => setEmail(e.target.value)} aria-invalid={Boolean(errors.email)} aria-describedby={errors.email ? 'email-err' : undefined} className={field} />
          {errors.email && <p id="email-err" className="mt-1 text-sm font-bold text-danger">{errors.email}</p>}
        </div>
        <div>
          <label htmlFor="phone" className="mb-1.5 block text-sm font-bold">{t.phone}</label>
          <input id="phone" type="tel" autoComplete="off" value={phone} onChange={(e) => setPhone(e.target.value)} className={field} />
        </div>

        <div aria-live="polite">
          {errors.form && (
            <p role="alert" className="rounded-lg bg-danger-bg px-3 py-2 text-sm font-bold text-danger">
              {errors.form}{' '}
              {partialId && (
                <Link to={`/contractors/${partialId}`} className="underline">{es.contractors.result.toDetail}</Link>
              )}
            </p>
          )}
        </div>

        <div className="flex flex-wrap justify-end gap-3">
          <Link to="/contractors" className="inline-flex min-h-11 items-center rounded-lg border border-line px-5 font-bold">{es.common.cancel}</Link>
          <button type="submit" disabled={submitting} className="min-h-11 rounded-lg bg-accent px-5 font-bold text-accent-ink disabled:opacity-60">
            {submitting ? t.submitting : t.submit}
          </button>
        </div>
      </form>
    </div>
  )
}
