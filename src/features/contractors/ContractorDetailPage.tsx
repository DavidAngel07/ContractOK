import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { formatDate, formatDateTime } from '../../lib/utils'
import { StatusPill } from '../../components/StatusPill'
import { useAccount } from '../account/useAccount'
import { InviteResult } from './InviteResult'
import { contractorStatusTone, invitationState, invitationTone, type InvitationRow } from './utils'

type Contractor = {
  id: string
  kind: 'natural' | 'company'
  display_name: string
  legal_name: string | null
  tax_id: string | null
  email: string
  phone: string | null
  status: string
  created_at: string
}
type Worker = { id: string; full_name: string; id_number: string; job_title: string | null; status: string }
type Fresh = { token: string; expiresAt: string }

export function ContractorDetailPage() {
  const { id = '' } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { account, can } = useAccount()
  const [fresh, setFresh] = useState<Fresh | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  const t = es.contractors
  const d = t.detail

  const contractor = useQuery({
    queryKey: ['contractor', id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('contractors')
        .select('id, kind, display_name, legal_name, tax_id, email, phone, status, created_at')
        .eq('id', id)
        .is('archived_at', null)
        .maybeSingle()
      if (error) throw error
      return data as Contractor | null
    },
  })

  const invitations = useQuery({
    queryKey: ['invitations', id],
    queryFn: async () => {
      // Se piden columnas concretas: token_hash no es legible desde el cliente.
      const { data, error } = await supabase
        .from('invitations')
        .select('id, email, expires_at, used_at, revoked_at, created_at')
        .eq('contractor_id', id)
        .order('created_at', { ascending: false })
      if (error) throw error
      return (data ?? []) as InvitationRow[]
    },
  })

  const workers = useQuery({
    queryKey: ['workers', id],
    enabled: contractor.data?.kind === 'company',
    queryFn: async () => {
      const { data, error } = await supabase
        .from('workers')
        .select('id, full_name, id_number, job_title, status')
        .eq('contractor_id', id)
        .order('full_name')
      if (error) throw error
      return (data ?? []) as Worker[]
    },
  })

  const newLink = useMutation({
    mutationFn: async () => {
      const { data, error } = await supabase.rpc('create_invitation', { p_contractor_id: id })
      if (error || !data) throw error ?? new Error('sin datos')
      return data as { token: string; expires_at: string }
    },
    onSuccess: (data) => {
      setActionError(null)
      setFresh({ token: data.token, expiresAt: data.expires_at })
      queryClient.invalidateQueries({ queryKey: ['invitations', id] })
    },
    onError: () => setActionError(d.linkError),
  })

  const revoke = useMutation({
    mutationFn: async (invitationId: string) => {
      const { error } = await supabase.rpc('revoke_invitation', { p_invitation_id: invitationId })
      if (error) throw error
    },
    onSuccess: () => {
      setActionError(null)
      setFresh(null)
      queryClient.invalidateQueries({ queryKey: ['invitations', id] })
    },
    onError: () => setActionError(d.revokeError),
  })

  const archive = useMutation({
    mutationFn: async () => {
      const { error } = await supabase.from('contractors').update({ archived_at: new Date().toISOString() }).eq('id', id)
      if (error) throw error
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['contractors'] })
      navigate('/contractors')
    },
    onError: () => setActionError(d.archiveError),
  })

  if (contractor.isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  if (contractor.error) return <p role="alert" className="rounded-xl bg-danger-bg px-4 py-3 font-bold text-danger">{es.common.loadError}</p>
  const c = contractor.data
  if (!c) {
    return (
      <div className="flex flex-col gap-3">
        <p>{es.common.notFound}</p>
        <Link to="/contractors" className="font-bold text-link underline">{es.common.back}</Link>
      </div>
    )
  }

  const canManage = can('contractors.manage')
  const dl = (label: string, value: string | null) => (
    <div>
      <dt className="text-sm text-muted">{label}</dt>
      <dd className="font-bold">{value || <span className="font-normal text-muted">{d.pending}</span>}</dd>
    </div>
  )

  return (
    <div className="flex flex-col gap-6">
      <Link to="/contractors" className="text-sm font-bold text-link underline">← {t.title}</Link>

      <div className="flex flex-wrap items-center gap-3">
        <h1 className="text-3xl font-extrabold tracking-tight">{c.display_name}</h1>
        <StatusPill tone={contractorStatusTone[c.status] ?? 'neutral'}>
          {t.status[c.status as keyof typeof t.status] ?? c.status}
        </StatusPill>
        <span className="text-muted">{t.kind[c.kind]}</span>
      </div>

      <section className="card p-6" aria-labelledby="data-title">
        <h2 id="data-title" className="text-xl font-bold">{d.data}</h2>
        <dl className="mt-4 grid gap-4 sm:grid-cols-2">
          {dl(d.legalName, c.legal_name)}
          {dl(d.taxId, c.tax_id)}
          {dl(d.email, c.email)}
          {dl(d.phone, c.phone)}
        </dl>
      </section>

      {fresh && account && (
        <InviteResult
          token={fresh.token}
          expiresAt={fresh.expiresAt}
          contractorName={c.display_name}
          contractorEmail={c.email}
          contractorPhone={c.phone}
          companyName={account.companyName}
          title={t.result.newLink}
        />
      )}

      <section className="card p-6" aria-labelledby="inv-title">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 id="inv-title" className="text-xl font-bold">{d.invitations}</h2>
          {canManage && (
            <button type="button" onClick={() => newLink.mutate()} disabled={newLink.isPending} className="btn btn-primary btn-sm">
              {newLink.isPending ? d.generating : d.generateLink}
            </button>
          )}
        </div>
        <div aria-live="polite">
          {actionError && <p role="alert" className="mt-3 rounded-xl bg-danger-bg px-3 py-2 text-sm font-bold text-danger">{actionError}</p>}
        </div>
        {invitations.data && invitations.data.length === 0 && <p className="mt-3 text-muted">{d.noInvitations}</p>}
        {invitations.data && invitations.data.length > 0 && (
          <div className="mt-4 overflow-x-auto">
            <table className="w-full min-w-120 text-left text-sm">
              <thead className="border-b border-line bg-gray-soft text-muted">
                <tr>
                  <th scope="col" className="py-2 pr-4 font-bold">{d.invCreated}</th>
                  <th scope="col" className="py-2 pr-4 font-bold">{d.invExpires}</th>
                  <th scope="col" className="py-2 pr-4 font-bold">{d.invState}</th>
                  <th scope="col" className="py-2 font-bold">{d.invActions}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {invitations.data.map((inv) => {
                  const state = invitationState(inv)
                  return (
                    <tr key={inv.id}>
                      <td className="py-2.5 pr-4">{formatDateTime(inv.created_at)}</td>
                      <td className="py-2.5 pr-4">{formatDateTime(inv.expires_at)}</td>
                      <td className="py-2.5 pr-4"><StatusPill tone={invitationTone[state]}>{t.invitationState[state]}</StatusPill></td>
                      <td className="py-2.5">
                        {canManage && state === 'valid' && (
                          <button type="button" onClick={() => revoke.mutate(inv.id)} disabled={revoke.isPending} className="btn btn-secondary btn-sm">
                            {d.revoke}
                          </button>
                        )}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {c.kind === 'company' && (
        <section className="card p-6" aria-labelledby="workers-title">
          <h2 id="workers-title" className="text-xl font-bold">{d.workers}</h2>
          {workers.data && workers.data.length === 0 && <p className="mt-3 text-muted">{d.noWorkers}</p>}
          {workers.data && workers.data.length > 0 && (
            <div className="mt-4 overflow-x-auto">
              <table className="w-full min-w-120 text-left text-sm">
                <thead className="border-b border-line bg-gray-soft text-muted">
                  <tr>
                    <th scope="col" className="py-2 pr-4 font-bold">{d.workerName}</th>
                    <th scope="col" className="py-2 pr-4 font-bold">{d.workerId}</th>
                    <th scope="col" className="py-2 font-bold">{d.workerJob}</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {workers.data.map((w) => (
                    <tr key={w.id}>
                      <td className="py-2.5 pr-4 font-bold">{w.full_name}</td>
                      <td className="py-2.5 pr-4">{w.id_number}</td>
                      <td className="py-2.5">{w.job_title ?? '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      )}

      <p className="text-sm text-muted">{formatDate(c.created_at)}</p>

      {canManage && (
        <div>
          <button
            type="button"
            onClick={() => { if (window.confirm(d.archiveConfirm)) archive.mutate() }}
            disabled={archive.isPending}
            className="btn btn-danger-outline"
          >
            {d.archive}
          </button>
        </div>
      )}
    </div>
  )
}
