import { useEffect, useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { es } from '../../i18n/es'
import { PROFILE_EDITABLE } from './progress'

type Contractor = {
  id: string
  display_name: string
  legal_name: string | null
  tax_id: string | null
  phone: string | null
  email: string
  status: string
}

export function ProfileForm({ contractorId }: { contractorId: string }) {
  const queryClient = useQueryClient()
  const t = es.portal
  const [legalName, setLegalName] = useState('')
  const [taxId, setTaxId] = useState('')
  const [phone, setPhone] = useState('')
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null)

  const { data, isLoading, error } = useQuery({
    queryKey: ['portal-contractor', contractorId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('contractors')
        .select('id, display_name, legal_name, tax_id, phone, email, status')
        .eq('id', contractorId)
        .maybeSingle()
      if (error) throw error
      return data as Contractor | null
    },
  })

  useEffect(() => {
    if (!data) return
    setLegalName(data.legal_name ?? data.display_name)
    setTaxId(data.tax_id ?? '')
    setPhone(data.phone ?? '')
  }, [data])

  const save = useMutation({
    mutationFn: async () => {
      const { error } = await supabase.rpc('contractor_update_profile', {
        p_contractor_id: contractorId,
        p_legal_name: legalName,
        p_tax_id: taxId,
        p_phone: phone,
      })
      if (error) throw error
    },
    onSuccess: async () => {
      setMessage({ ok: true, text: t.saved })
      await queryClient.invalidateQueries({ queryKey: ['portal-contractor', contractorId] })
    },
    onError: (err: { code?: string; message?: string }) => {
      if (err.code === '23505') setMessage({ ok: false, text: t.duplicateTaxId })
      else if (err.code === '42501' && err.message) setMessage({ ok: false, text: err.message })
      else setMessage({ ok: false, text: t.saveError })
    },
  })

  if (isLoading) return <p role="status" className="text-muted">{es.loading}</p>
  if (error || !data) return <p role="alert" className="text-danger">{es.common.loadError}</p>

  const editable = PROFILE_EDITABLE.includes(data.status)

  function onSubmit(event: FormEvent) {
    event.preventDefault()
    setMessage(null)
    save.mutate()
  }

  return (
    <form onSubmit={onSubmit} className="mt-4 flex flex-col gap-4">
      {!editable && <p className="rounded-xl bg-warn-box px-3 py-2 text-sm font-bold">{t.locked}</p>}
      <div>
        <label htmlFor="legal-name" className="mb-1.5 block text-sm font-bold">{t.legalName}</label>
        <input id="legal-name" value={legalName} onChange={(e) => setLegalName(e.target.value)} disabled={!editable} className="field" />
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <label htmlFor="tax-id" className="mb-1.5 block text-sm font-bold">{t.taxId}</label>
          <input id="tax-id" value={taxId} onChange={(e) => setTaxId(e.target.value)} disabled={!editable} inputMode="numeric" className="field" />
        </div>
        <div>
          <label htmlFor="phone" className="mb-1.5 block text-sm font-bold">{t.phone}</label>
          <input id="phone" type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} disabled={!editable} className="field" />
        </div>
      </div>
      <div>
        <label htmlFor="email-ro" className="mb-1.5 block text-sm font-bold">{t.email}</label>
        <input id="email-ro" value={data.email} readOnly disabled className="field" />
      </div>
      <div aria-live="polite">
        {message && (
          <p role={message.ok ? 'status' : 'alert'} className={`rounded-xl px-3 py-2 text-sm font-bold ${message.ok ? 'bg-ok-box text-ok-ink' : 'bg-danger-bg text-danger'}`}>
            {message.text}
          </p>
        )}
      </div>
      {editable && (
        <button type="submit" disabled={save.isPending} className="btn btn-primary self-start">
          {save.isPending ? t.saving : t.save}
        </button>
      )}
    </form>
  )
}
