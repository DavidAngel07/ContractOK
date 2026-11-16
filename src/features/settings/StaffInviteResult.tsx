import { useState } from 'react'
import { es } from '../../i18n/es'
import { buildGmailUrl, buildMailto, buildOutlookUrl, buildWhatsAppUrl } from '../contractors/utils'

export function StaffInviteResult({ email, roleName, companyName }: { email: string; roleName: string; companyName: string }) {
  const t = es.settings.users
  const link = `${window.location.origin}/ingreso`
  const subject = t.mailSubject(companyName)
  const message = t.mailBody(companyName, roleName, link)
  const [copied, setCopied] = useState(false)
  const channel = 'btn btn-secondary btn-sm'

  async function copy() {
    try { await navigator.clipboard.writeText(link); setCopied(true) } catch { /* el enlace queda visible para copiarlo */ }
  }

  return (
    <section className="card p-6" aria-labelledby="staff-result-title">
      <h3 id="staff-result-title" className="text-xl font-bold">{t.resultTitle}</h3>
      <p className="mt-1 text-muted">{t.resultBody(email)}</p>
      <label htmlFor="staff-link" className="mt-4 block text-sm font-bold">{t.loginLink}</label>
      <div className="mt-1.5 flex flex-wrap gap-2">
        <input id="staff-link" readOnly value={link} onFocus={(e) => e.currentTarget.select()} className="field min-w-0 flex-1 text-sm" />
        <button type="button" onClick={copy} className="btn btn-primary btn-sm">{t.copyLink}</button>
      </div>
      <p role="status" className="mt-1 min-h-6 text-sm font-bold text-link">{copied ? t.linkCopied : ''}</p>
      <p className="mt-2 text-sm font-bold">{t.sendBy}</p>
      <div className="mt-1.5 flex flex-wrap gap-2">
        <a className={channel} target="_blank" rel="noopener noreferrer" href={buildGmailUrl(email, subject, message)}>{es.contractors.result.gmail}</a>
        <a className={channel} target="_blank" rel="noopener noreferrer" href={buildOutlookUrl(email, subject, message)}>{es.contractors.result.outlook}</a>
        <a className={channel} target="_blank" rel="noopener noreferrer" href={buildWhatsAppUrl(null, message)}>{es.contractors.result.whatsapp}</a>
        <a className={channel} href={buildMailto(email, subject, message)}>{es.contractors.result.mailApp}</a>
      </div>
    </section>
  )
}
