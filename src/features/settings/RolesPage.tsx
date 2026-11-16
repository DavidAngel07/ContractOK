import { useEffect, useState, type FormEvent } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { Notice } from '../../components/Notice'
import { useAccount } from '../account/useAccount'
import { usePermissionCatalog, type DbError } from './hooks'

type Scope = 'all' | 'assigned'
type RoleRow = {
  id: string
  name: string
  description: string | null
  is_system: boolean
  role_permissions: { permission_key: string; scope: Scope }[]
  memberships: { count: number }[] | null
}

// Responsabilidades que pueden limitarse a los contratistas asignados a cada persona.
export const SCOPED_PERMISSIONS = [
  'contractors.manage', 'documents.upload_on_behalf', 'documents.review', 'reports.activity_validate',
  'periods.manage', 'reports.view', 'alerts.receive',
]

function RoleEditor({ role, onDone }: { role: RoleRow | null; onDone: () => void }) {
  const { account } = useAccount()
  const queryClient = useQueryClient()
  const catalog = usePermissionCatalog()
  const t = es.settings.roles
  const [name, setName] = useState(role?.name ?? '')
  const [description, setDescription] = useState(role?.description ?? '')
  const [perms, setPerms] = useState<Record<string, Scope>>(
    Object.fromEntries((role?.role_permissions ?? []).map((p) => [p.permission_key, p.scope])),
  )
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [nameError, setNameError] = useState<string | null>(null)
  useEffect(() => setError(null), [role?.id])

  async function submit(event: FormEvent) {
    event.preventDefault()
    setError(null)
    if (!name.trim()) { setNameError(es.settings.required); return }
    setNameError(null)
    if (!role && Object.keys(perms).length === 0) { setError(t.noneSelected); return }
    setBusy(true)
    const fail = (err: DbError) => {
      setBusy(false)
      setError(err.code === '23505' ? t.duplicate : err.code === '23514' ? t.lastAdmin : es.settings.saveError)
    }
    let roleId = role?.id
    if (!role) {
      const { data, error: e } = await supabase.from('roles').insert({ company_id: account!.companyId, name: name.trim(), description: description.trim() || null }).select('id').single()
      if (e || !data) return fail((e ?? {}) as DbError)
      roleId = data.id as string
    } else {
      const patch = role.is_system ? { description: description.trim() || null } : { name: name.trim(), description: description.trim() || null }
      const { error: e } = await supabase.from('roles').update(patch).eq('id', role.id)
      if (e) return fail(e as DbError)
    }
    const rows = Object.entries(perms).map(([permission_key, scope]) => ({ role_id: roleId!, permission_key, scope }))
    if (rows.length > 0) {
      const { error: e } = await supabase.from('role_permissions').upsert(rows, { onConflict: 'role_id,permission_key' })
      if (e) return fail(e as DbError)
    }
    const removed = (role?.role_permissions ?? []).map((p) => p.permission_key).filter((k) => !(k in perms))
    if (removed.length > 0) {
      const { error: e } = await supabase.from('role_permissions').delete().eq('role_id', roleId!).in('permission_key', removed)
      if (e) return fail(e as DbError)
    }
    setBusy(false)
    await queryClient.invalidateQueries({ queryKey: ['roles-admin'] })
    await queryClient.invalidateQueries({ queryKey: ['account-context'] })
    onDone()
  }

  async function remove() {
    if (!role || !window.confirm(t.deleteConfirm)) return
    setBusy(true)
    const { error: e } = await supabase.from('roles').delete().eq('id', role.id)
    setBusy(false)
    if (e) {
      const code = (e as DbError).code
      setError(code === '23503' ? t.hasMembers : code === '23514' ? t.systemDelete : es.settings.saveError)
      return
    }
    await queryClient.invalidateQueries({ queryKey: ['roles-admin'] })
    onDone()
  }

  return (
    <form onSubmit={submit} noValidate className="card flex flex-col gap-5 p-6">
      <div>
        <label htmlFor="r-name" className="mb-1.5 block text-sm font-bold">{t.name}</label>
        <input id="r-name" value={name} disabled={role?.is_system} onChange={(e) => setName(e.target.value)} aria-invalid={Boolean(nameError)} className="field" />
        {nameError && <p className="mt-1 text-sm font-bold text-danger">{nameError}</p>}
      </div>
      <div>
        <label htmlFor="r-desc" className="mb-1.5 block text-sm font-bold">{t.description}</label>
        <input id="r-desc" value={description} onChange={(e) => setDescription(e.target.value)} className="field" />
      </div>

      <fieldset>
        <legend className="mb-1 text-sm font-bold">{t.permissions}</legend>
        <ul className="divide-y divide-line">
          {(catalog.data ?? []).map((p) => {
            const on = p.key in perms
            const scoped = SCOPED_PERMISSIONS.includes(p.key)
            return (
              <li key={p.key} className="flex flex-wrap items-center justify-between gap-x-6 gap-y-1 py-2">
                <label className="flex min-h-11 flex-1 cursor-pointer items-center gap-3">
                  <input type="checkbox" checked={on}
                    onChange={(e) => setPerms((prev) => {
                      const next = { ...prev }
                      if (e.target.checked) next[p.key] = 'all'
                      else delete next[p.key]
                      return next
                    })} />
                  <span className="font-semibold">{t.permissionLabels[p.key] ?? p.description}</span>
                </label>
                {on && scoped ? (
                  <div>
                    <label htmlFor={`sc-${p.key}`} className="sr-only">{t.scopeLabel}: {t.permissionLabels[p.key]}</label>
                    <select id={`sc-${p.key}`} value={perms[p.key]} onChange={(e) => setPerms((prev) => ({ ...prev, [p.key]: e.target.value as Scope }))} className="field field-auto text-sm">
                      <option value="all">{t.scopeAll}</option>
                      <option value="assigned">{t.scopeAssigned}</option>
                    </select>
                  </div>
                ) : on ? (
                  <span className="text-sm text-muted">{t.noScopeNote}</span>
                ) : null}
              </li>
            )
          })}
        </ul>
      </fieldset>

      <div aria-live="polite">{error && <Notice kind="error">{error}</Notice>}</div>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <button type="submit" disabled={busy} className="btn btn-primary">{busy ? es.settings.saving : es.settings.save}</button>
        {role && !role.is_system && <button type="button" onClick={remove} disabled={busy} className="btn btn-danger-outline">{es.settings.delete}</button>}
      </div>
    </form>
  )
}

export function RolesPage() {
  const [selected, setSelected] = useState<string | null>(null) // id, 'new' o null
  const t = es.settings.roles
  const roles = useQuery({
    queryKey: ['roles-admin'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('roles')
        .select('id, name, description, is_system, role_permissions(permission_key, scope), memberships(count)')
        .order('name')
      if (error) throw error
      return (data ?? []) as unknown as RoleRow[]
    },
  })

  if (roles.isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  if (roles.error) return <Notice kind="error">{es.common.loadError}</Notice>
  const list = roles.data ?? []
  const current = list.find((r) => r.id === selected) ?? null

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h2 className="text-xl font-bold">{t.title}</h2>
        <p className="text-muted">{t.intro}</p>
      </div>
      <div className="grid gap-6 md:grid-cols-[18rem_1fr]">
        <nav aria-label={t.listLabel} className="flex flex-col gap-2">
          <ul className="flex flex-col gap-2">
            {list.map((r) => (
              <li key={r.id}>
                <button type="button" onClick={() => setSelected(r.id)} aria-current={selected === r.id ? 'true' : undefined}
                  className={`w-full rounded-xl border px-4 py-3 text-left ${selected === r.id ? 'border-accent bg-accent-wash' : 'border-line bg-surface'}`}>
                  <span className="block font-bold">{r.name}</span>
                  <span className="text-sm text-muted">
                    {t.members(r.memberships?.[0]?.count ?? 0)}{r.is_system ? ` · ${t.system}` : ''}
                  </span>
                </button>
              </li>
            ))}
          </ul>
          <button type="button" onClick={() => setSelected('new')} className="btn btn-secondary">{t.newRole}</button>
        </nav>
        <div>
          {selected === 'new' && <RoleEditor key="new" role={null} onDone={() => setSelected(null)} />}
          {current && <RoleEditor key={current.id} role={current} onDone={() => setSelected(null)} />}
          {!selected && <p className="card p-6 text-muted">{t.select}</p>}
        </div>
      </div>
    </div>
  )
}
