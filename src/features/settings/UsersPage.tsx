import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { formatDate } from '../../lib/utils'
import { Notice } from '../../components/Notice'
import { StatusPill } from '../../components/StatusPill'
import { useAuth } from '../auth/AuthProvider'
import { useAccount } from '../account/useAccount'
import { isValidEmail } from '../contractors/utils'
import { StaffInviteResult } from './StaffInviteResult'
import type { DbError } from './hooks'

type Member = { id: string; user_id: string; role_id: string; status: string }
type Person = { id: string; full_name: string | null; email: string | null }
type Role = { id: string; name: string }
type Pending = { id: string; email: string; role_id: string; expires_at: string }

export function UsersPage() {
  const { session } = useAuth()
  const { account } = useAccount()
  const queryClient = useQueryClient()
  const t = es.settings.users
  const companyId = account?.companyId
  const [email, setEmail] = useState('')
  const [roleId, setRoleId] = useState('')
  const [emailError, setEmailError] = useState<string | null>(null)
  const [notice, setNotice] = useState<{ kind: 'ok' | 'error'; text: string } | null>(null)
  const [invited, setInvited] = useState<{ email: string; roleName: string } | null>(null)

  const data = useQuery({
    queryKey: ['users-admin', companyId],
    enabled: Boolean(companyId),
    queryFn: async () => {
      const [m, r, p] = await Promise.all([
        supabase.from('memberships').select('id, user_id, role_id, status').eq('company_id', companyId!).order('created_at'),
        supabase.from('roles').select('id, name').order('name'),
        supabase.from('staff_invitations').select('id, email, role_id, expires_at').eq('status', 'pending').order('created_at', { ascending: false }),
      ])
      if (m.error) throw m.error
      if (r.error) throw r.error
      if (p.error) throw p.error
      const ids = (m.data ?? []).map((x) => x.user_id as string)
      const prof = ids.length ? await supabase.from('profiles').select('id, full_name, email').in('id', ids) : { data: [], error: null }
      if (prof.error) throw prof.error
      return {
        members: (m.data ?? []) as Member[],
        roles: (r.data ?? []) as Role[],
        pending: (p.data ?? []) as Pending[],
        people: new Map(((prof.data ?? []) as Person[]).map((x) => [x.id, x])),
      }
    },
  })
  const refresh = () => queryClient.invalidateQueries({ queryKey: ['users-admin', companyId] })
  const fail = (e: DbError, fallback: string) =>
    setNotice({ kind: 'error', text: e.code === '23514' ? t.lastAdmin : fallback })

  const change = useMutation({
    mutationFn: async (v: { id: string; patch: { role_id?: string; status?: string } }) => {
      const { error } = await supabase.from('memberships').update(v.patch).eq('id', v.id)
      if (error) throw error
    },
    onSuccess: async () => { setNotice({ kind: 'ok', text: t.roleChanged }); await refresh(); await queryClient.invalidateQueries({ queryKey: ['account-context'] }) },
    onError: (e: DbError) => fail(e, t.changeError),
  })

  const invite = useMutation({
    mutationFn: async () => {
      const { error } = await supabase.rpc('invite_staff', { p_company_id: companyId!, p_email: email.trim(), p_role_id: roleId })
      if (error) throw error
    },
    onSuccess: async () => {
      const roleName = data.data?.roles.find((r) => r.id === roleId)?.name ?? ''
      setInvited({ email: email.trim().toLowerCase(), roleName })
      setEmail('')
      setNotice(null)
      await refresh()
    },
    onError: (e: DbError) => setNotice({ kind: 'error', text: e.code === '23505' ? t.alreadyMember : t.inviteError }),
  })

  const revoke = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.rpc('revoke_staff_invitation', { p_invitation_id: id })
      if (error) throw error
    },
    onSuccess: refresh,
    onError: () => setNotice({ kind: 'error', text: t.changeError }),
  })

  function onInvite(event: FormEvent) {
    event.preventDefault()
    setNotice(null)
    setInvited(null)
    if (!isValidEmail(email)) { setEmailError(t.emailInvalid); return }
    setEmailError(null)
    invite.mutate()
  }

  if (data.isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  if (data.error || !data.data) return <Notice kind="error">{es.common.loadError}</Notice>
  const { members, roles, pending, people } = data.data
  const roleName = (id: string) => roles.find((r) => r.id === id)?.name ?? '—'
  const effectiveRole = roleId || roles[0]?.id || ''

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h2 className="text-xl font-bold">{t.title}</h2>
        <p className="text-muted">{t.intro}</p>
      </div>
      <div aria-live="polite">{notice && <Notice kind={notice.kind}>{notice.text}</Notice>}</div>

      <section className="card p-6" aria-labelledby="inv-title">
        <h3 id="inv-title" className="text-lg font-bold">{t.inviteTitle}</h3>
        <form onSubmit={onInvite} noValidate className="mt-4 grid gap-4 sm:grid-cols-[1fr_14rem_auto] sm:items-end">
          <div>
            <label htmlFor="u-email" className="mb-1.5 block text-sm font-bold">{t.email}</label>
            <input id="u-email" type="email" autoComplete="off" value={email} onChange={(e) => setEmail(e.target.value)} aria-invalid={Boolean(emailError)} className="field" />
            {emailError && <p className="mt-1 text-sm font-bold text-danger">{emailError}</p>}
          </div>
          <div>
            <label htmlFor="u-role" className="mb-1.5 block text-sm font-bold">{t.role}</label>
            <select id="u-role" value={effectiveRole} onChange={(e) => setRoleId(e.target.value)} className="field">
              {roles.map((r) => <option key={r.id} value={r.id}>{r.name}</option>)}
            </select>
          </div>
          <button type="submit" disabled={invite.isPending} className="btn btn-primary">{invite.isPending ? t.inviting : t.invite}</button>
        </form>
      </section>

      {invited && account && <StaffInviteResult email={invited.email} roleName={invited.roleName} companyName={account.companyName} />}

      <section className="card overflow-hidden" aria-labelledby="team-title">
        <h3 id="team-title" className="border-b border-line bg-gray-soft px-5 py-3 font-bold">{t.teamTitle}</h3>
        <div className="overflow-x-auto">
          <table className="w-full min-w-170 text-left text-sm">
            <thead className="text-muted">
              <tr>
                <th scope="col" className="px-5 py-2 font-bold">{t.columns.person}</th>
                <th scope="col" className="px-3 py-2 font-bold">{t.columns.role}</th>
                <th scope="col" className="px-3 py-2 font-bold">{t.columns.status}</th>
                <th scope="col" className="px-5 py-2"><span className="sr-only">{t.columns.actions}</span></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {members.map((m) => {
                const person = people.get(m.user_id)
                const isMe = m.user_id === session?.user.id
                return (
                  <tr key={m.id}>
                    <th scope="row" className="px-5 py-3 font-bold">
                      {person?.full_name || person?.email || '—'} {isMe && <span className="font-normal text-muted">{t.you}</span>}
                      <span className="block text-sm font-normal text-muted">{person?.email}</span>
                    </th>
                    <td className="px-3 py-3">
                      <label htmlFor={`role-${m.id}`} className="sr-only">{t.role}: {person?.email}</label>
                      <select id={`role-${m.id}`} value={m.role_id} disabled={change.isPending}
                        onChange={(e) => change.mutate({ id: m.id, patch: { role_id: e.target.value } })} className="field field-auto text-sm">
                        {roles.map((r) => <option key={r.id} value={r.id}>{r.name}</option>)}
                      </select>
                    </td>
                    <td className="px-3 py-3">
                      <StatusPill tone={m.status === 'active' ? 'ok' : 'neutral'}>{t.status[m.status] ?? m.status}</StatusPill>
                    </td>
                    <td className="px-5 py-3 text-right">
                      {!isMe && (
                        <button type="button" disabled={change.isPending} className="btn btn-secondary btn-sm"
                          onClick={() => change.mutate({ id: m.id, patch: { status: m.status === 'active' ? 'disabled' : 'active' } })}>
                          {m.status === 'active' ? t.disable : t.enable}
                        </button>
                      )}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </section>

      <section className="card p-6" aria-labelledby="pend-title">
        <h3 id="pend-title" className="text-lg font-bold">{t.pendingTitle}</h3>
        {pending.length === 0 ? (
          <p className="mt-2 text-muted">{t.noPending}</p>
        ) : (
          <ul className="mt-2 divide-y divide-line">
            {pending.map((p) => (
              <li key={p.id} className="flex flex-wrap items-center justify-between gap-3 py-3">
                <div>
                  <p className="font-bold">{p.email}</p>
                  <p className="text-sm text-muted">{roleName(p.role_id)} · {t.expires} {formatDate(p.expires_at)}</p>
                </div>
                <button type="button" onClick={() => revoke.mutate(p.id)} disabled={revoke.isPending} className="btn btn-secondary btn-sm">{t.revoke}</button>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  )
}
