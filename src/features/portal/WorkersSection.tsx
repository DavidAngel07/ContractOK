import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'

type Worker = { id: string; full_name: string; id_number: string; job_title: string | null }

export function WorkersSection({ contractorId, companyId }: { contractorId: string; companyId: string }) {
  const queryClient = useQueryClient()
  const t = es.portal
  const [name, setName] = useState('')
  const [idNumber, setIdNumber] = useState('')
  const [job, setJob] = useState('')
  const [error, setError] = useState<string | null>(null)

  const workers = useQuery({
    queryKey: ['portal-workers', contractorId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('workers')
        .select('id, full_name, id_number, job_title')
        .eq('contractor_id', contractorId)
        .order('full_name')
      if (error) throw error
      return (data ?? []) as Worker[]
    },
  })

  const refresh = () => queryClient.invalidateQueries({ queryKey: ['portal-workers', contractorId] })

  const add = useMutation({
    mutationFn: async () => {
      const { error } = await supabase.from('workers').insert({
        company_id: companyId,
        contractor_id: contractorId,
        full_name: name.trim(),
        id_number: idNumber.trim(),
        job_title: job.trim() || null,
      })
      if (error) throw error
    },
    onSuccess: async () => {
      setName('')
      setIdNumber('')
      setJob('')
      setError(null)
      await refresh()
    },
    onError: (err: { code?: string }) => setError(err.code === '23505' ? t.duplicateWorker : t.workerError),
  })

  const remove = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('workers').delete().eq('id', id)
      if (error) throw error
    },
    onSuccess: refresh,
    onError: () => setError(t.workerError),
  })

  function onSubmit(event: FormEvent) {
    event.preventDefault()
    if (!name.trim() || !idNumber.trim()) {
      setError(t.workerRequired)
      return
    }
    setError(null)
    add.mutate()
  }

  return (
    <div>
      <p className="mt-1 text-muted">{t.workersIntro}</p>

      {workers.data && workers.data.length === 0 && <p className="mt-4 text-muted">{t.noWorkers}</p>}
      {workers.data && workers.data.length > 0 && (
        <ul className="mt-4 flex flex-col divide-y divide-line">
          {workers.data.map((w) => (
            <li key={w.id} className="flex flex-wrap items-center justify-between gap-3 py-3">
              <div>
                <p className="font-bold">{w.full_name}</p>
                <p className="text-sm text-muted">
                  {w.id_number}
                  {w.job_title ? ` · ${w.job_title}` : ''}
                </p>
              </div>
              <button
                type="button"
                className="btn btn-danger-outline btn-sm"
                onClick={() => { if (window.confirm(t.removeConfirm(w.full_name))) remove.mutate(w.id) }}
              >
                {t.removeWorker}
              </button>
            </li>
          ))}
        </ul>
      )}

      <form onSubmit={onSubmit} noValidate className="mt-6 grid gap-4 rounded-2xl bg-gray-soft p-4 sm:grid-cols-3">
        <div>
          <label htmlFor="w-name" className="mb-1.5 block text-sm font-bold">{t.workerName}</label>
          <input id="w-name" value={name} onChange={(e) => setName(e.target.value)} className="field" />
        </div>
        <div>
          <label htmlFor="w-id" className="mb-1.5 block text-sm font-bold">{t.workerId}</label>
          <input id="w-id" value={idNumber} onChange={(e) => setIdNumber(e.target.value)} inputMode="numeric" className="field" />
        </div>
        <div>
          <label htmlFor="w-job" className="mb-1.5 block text-sm font-bold">{t.workerJob}</label>
          <input id="w-job" value={job} onChange={(e) => setJob(e.target.value)} className="field" />
        </div>
        <div className="sm:col-span-3" aria-live="polite">
          {error && <p role="alert" className="mb-3 rounded-xl bg-danger-bg px-3 py-2 text-sm font-bold text-danger">{error}</p>}
          <button type="submit" disabled={add.isPending} className="btn btn-primary">
            {add.isPending ? t.adding : t.addWorker}
          </button>
        </div>
      </form>
    </div>
  )
}
