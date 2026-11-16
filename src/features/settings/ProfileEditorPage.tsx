import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { safeReturn } from '../../lib/returnTo'
import { Notice } from '../../components/Notice'
import { useAccount } from '../account/useAccount'
import { PHASES, useDocumentTypes, type DbError } from './hooks'

type Kind = 'natural' | 'company' | 'both'
// Documentos incluidos en el perfil: id del documento → ¿es obligatorio?
type Selection = Record<string, boolean>

export function ProfileEditorPage() {
  const { id } = useParams()
  const isNew = !id
  const navigate = useNavigate()
  const [search] = useSearchParams()
  const back = safeReturn(search.get('return'), '/settings/profiles')
  const queryClient = useQueryClient()
  const { account } = useAccount()
  const docs = useDocumentTypes()
  const t = es.settings.profiles
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [kind, setKind] = useState<Kind>('natural')
  const [active, setActive] = useState(true)
  const [selected, setSelected] = useState<Selection>({})
  const [nameError, setNameError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  const profile = useQuery({
    queryKey: ['profile', id],
    enabled: !isNew,
    queryFn: async () => {
      const [p, items, used] = await Promise.all([
        supabase.from('requirement_profiles').select('id, name, description, contractor_kind, is_active').eq('id', id!).maybeSingle(),
        supabase.from('requirement_profile_items').select('document_type_id, is_mandatory').eq('requirement_profile_id', id!),
        supabase.from('contractors').select('id', { count: 'exact', head: true }).eq('requirement_profile_id', id!),
      ])
      if (p.error) throw p.error
      if (items.error) throw items.error
      return { profile: p.data, items: items.data ?? [], used: used.count ?? 0 }
    },
  })

  useEffect(() => {
    const d = profile.data
    if (!d?.profile) return
    setName(d.profile.name)
    setDescription(d.profile.description ?? '')
    setKind(d.profile.contractor_kind as Kind)
    setActive(d.profile.is_active)
    setSelected(Object.fromEntries(d.items.map((i) => [i.document_type_id as string, i.is_mandatory as boolean])))
  }, [profile.data])

  async function submit(event: FormEvent) {
    event.preventDefault()
    setMessage(null)
    if (!name.trim()) { setNameError(es.settings.required); return }
    setNameError(null)
    setBusy(true)
    const base = { name: name.trim(), description: description.trim() || null, contractor_kind: kind, is_active: active }
    let profileId = id
    if (isNew) {
      const { data, error } = await supabase.from('requirement_profiles').insert({ ...base, company_id: account!.companyId }).select('id').single()
      if (error || !data) {
        setBusy(false)
        setMessage((error as DbError | null)?.code === '23505' ? t.duplicate : es.settings.saveError)
        return
      }
      profileId = data.id as string
    } else {
      const { error } = await supabase.from('requirement_profiles').update(base).eq('id', id!)
      if (error) {
        setBusy(false)
        setMessage((error as DbError).code === '23505' ? t.duplicate : es.settings.saveError)
        return
      }
    }

    const rows = Object.entries(selected).map(([docId, mandatory]) => ({
      requirement_profile_id: profileId!, document_type_id: docId, company_id: account!.companyId, is_mandatory: mandatory,
    }))
    if (rows.length > 0) {
      const { error } = await supabase.from('requirement_profile_items').upsert(rows, { onConflict: 'requirement_profile_id,document_type_id' })
      if (error) { setBusy(false); setMessage(es.settings.saveError); return }
    }
    const previous = (profile.data?.items ?? []).map((i) => i.document_type_id as string)
    const removed = previous.filter((docId) => !(docId in selected))
    if (removed.length > 0) {
      const { error } = await supabase.from('requirement_profile_items').delete().eq('requirement_profile_id', profileId!).in('document_type_id', removed)
      if (error) { setBusy(false); setMessage(es.settings.saveError); return }
    }
    setBusy(false)
    await queryClient.invalidateQueries({ queryKey: ['profiles'] })
    await queryClient.invalidateQueries({ queryKey: ['profile', profileId] })
    navigate(back)
  }

  async function remove() {
    if (!window.confirm(t.deleteConfirm)) return
    setBusy(true)
    const { error } = await supabase.from('requirement_profiles').delete().eq('id', id!)
    setBusy(false)
    if (error) {
      setMessage((error as DbError).code === '23503' ? t.inUse : es.settings.saveError)
      return
    }
    await queryClient.invalidateQueries({ queryKey: ['profiles'] })
    navigate(back)
  }

  if (!isNew && profile.isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  if (!isNew && !profile.isLoading && !profile.data?.profile) return <Notice kind="error">{es.common.notFound}</Notice>
  if (docs.isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  const allDocs = docs.data ?? []
  const selectedCount = Object.keys(selected).length

  return (
    <form onSubmit={submit} noValidate className="mx-auto flex max-w-4xl flex-col gap-6">
      <div>
        <Link to={back} className="text-sm font-bold text-link underline">← {t.title}</Link>
        <h2 className="mt-2 text-2xl font-extrabold tracking-tight">{isNew ? t.newTitle : t.editTitle}</h2>
      </div>
      {!isNew && (profile.data?.used ?? 0) > 0 && <Notice kind="info">{t.usedBy(profile.data!.used)}</Notice>}

      <section className="card flex flex-col gap-4 p-6">
        <div>
          <label htmlFor="p-name" className="mb-1.5 block text-sm font-bold">{t.name}</label>
          <input id="p-name" value={name} onChange={(e) => setName(e.target.value)} aria-invalid={Boolean(nameError)} className="field" />
          {nameError && <p className="mt-1 text-sm font-bold text-danger">{nameError}</p>}
        </div>
        <div>
          <label htmlFor="p-desc" className="mb-1.5 block text-sm font-bold">{t.description}</label>
          <input id="p-desc" value={description} onChange={(e) => setDescription(e.target.value)} className="field" />
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label htmlFor="p-kind" className="mb-1.5 block text-sm font-bold">{t.kindLabel}</label>
            <select id="p-kind" value={kind} onChange={(e) => setKind(e.target.value as Kind)} className="field">
              {(['natural', 'company', 'both'] as const).map((k) => <option key={k} value={k}>{t.kind[k]}</option>)}
            </select>
          </div>
          <label className="flex min-h-11 cursor-pointer items-center gap-3 self-end font-bold">
            <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} />
            {t.active}
          </label>
        </div>
      </section>

      <section className="card p-6" aria-labelledby="req-title">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h3 id="req-title" className="text-xl font-bold">{t.requirements}</h3>
          <span className="pill pill-info">{t.selected(selectedCount)}</span>
        </div>
        {allDocs.length === 0 && <p className="mt-3 text-muted">{t.noDocs}</p>}
        {PHASES.map((phase) => {
          const rows = allDocs.filter((d) => d.phase === phase)
          if (rows.length === 0) return null
          return (
            <fieldset key={phase} className="mt-5">
              <legend className="mb-1 font-bold text-link">{es.settings.phase[phase]}</legend>
              <ul className="divide-y divide-line">
                {rows.map((d) => {
                  const included = d.id in selected
                  return (
                    <li key={d.id} className="flex flex-wrap items-center justify-between gap-x-6 gap-y-1 py-2">
                      <label className="flex min-h-11 flex-1 cursor-pointer items-center gap-3">
                        <input type="checkbox" checked={included}
                          onChange={(e) => setSelected((prev) => {
                            const next = { ...prev }
                            if (e.target.checked) next[d.id] = true
                            else delete next[d.id]
                            return next
                          })} />
                        <span>
                          <span className="font-semibold">{d.name}</span>{' '}
                          <span className="text-sm text-muted">· {d.owner_kind === 'worker' ? 'Trabajador' : 'Contratista'}{d.is_active ? '' : ` ${t.inactiveDoc}`}</span>
                        </span>
                      </label>
                      <label className={`flex min-h-11 items-center gap-2 text-sm ${included ? 'cursor-pointer' : 'opacity-50'}`}>
                        <input type="checkbox" disabled={!included} checked={included && selected[d.id]}
                          onChange={(e) => setSelected((prev) => ({ ...prev, [d.id]: e.target.checked }))} />
                        {t.mandatory}
                      </label>
                    </li>
                  )
                })}
              </ul>
            </fieldset>
          )
        })}
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
