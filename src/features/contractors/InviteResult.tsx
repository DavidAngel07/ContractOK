import { useRef, useState } from 'react'
import { es } from '../../i18n/es'
import { formatDateTime } from '../../lib/utils'
import { buildGmailUrl, buildInviteLink, buildMailto, buildOutlookUrl, buildWhatsAppUrl } from './utils'

type Props = {
  token: string
  expiresAt: string
  contractorName: string
  contractorEmail: string
  contractorPhone?: string | null
  companyName: string
  title: string
}

export function InviteResult({
  token,
  expiresAt,
  contractorName,
  contractorEmail,
  contractorPhone,
  companyName,
  title,
}: Props) {
  const link = buildInviteLink(window.location.origin, token)
  const inputRef = useRef<HTMLInputElement>(null)
  const [copied, setCopied] = useState<'link' | 'message' | null>(null)
  const expires = formatDateTime(expiresAt)
  const t = es.contractors.result

  const subject = t.mailSubject(companyName)
  const message = t.mailBody(contractorName, companyName, link, expires)

  async function copy(text: string, what: 'link' | 'message') {
    try {
      await navigator.clipboard.writeText(text)
      setCopied(what)
    } catch {
      if (what === 'link') inputRef.current?.select()
    }
  }

  const channel =
    'inline-flex min-h-11 items-center rounded-lg border border-line bg-surface px-4 text-sm font-bold'

  return (
    <section className="rounded-2xl border border-line bg-surface p-6" aria-labelledby="invite-result-title">
      <h2 id="invite-result-title" className="text-xl font-bold">
        {title}
      </h2>

      <label htmlFor="invite-link" className="mt-4 block text-sm font-bold">
        {t.linkLabel}
      </label>
      <div className="mt-1.5 flex flex-wrap gap-2">
        <input
          id="invite-link"
          ref={inputRef}
          readOnly
          value={link}
          onFocus={(e) => e.currentTarget.select()}
          className="min-h-11 min-w-0 flex-1 rounded-lg border border-line bg-bg px-3 text-sm"
        />
        <button
          type="button"
          onClick={() => copy(link, 'link')}
          className="min-h-11 rounded-lg bg-accent px-4 font-bold text-accent-ink"
        >
          {t.copy}
        </button>
      </div>

      <p className="mt-5 text-sm font-bold">{t.sendBy}</p>
      <div className="mt-1.5 flex flex-wrap gap-2">
        <a href={buildGmailUrl(contractorEmail, subject, message)} target="_blank" rel="noopener noreferrer" className={channel}>
          {t.gmail}
        </a>
        <a href={buildOutlookUrl(contractorEmail, subject, message)} target="_blank" rel="noopener noreferrer" className={channel}>
          {t.outlook}
        </a>
        <a href={buildWhatsAppUrl(contractorPhone, message)} target="_blank" rel="noopener noreferrer" className={channel}>
          {t.whatsapp}
        </a>
        <a href={buildMailto(contractorEmail, subject, message)} className={channel}>
          {t.mailApp}
        </a>
        <button type="button" onClick={() => copy(message, 'message')} className={channel}>
          {t.copyMessage}
        </button>
      </div>
      <p className="mt-2 text-sm text-muted">{t.mailHelp}</p>

      <p role="status" className="mt-2 min-h-6 text-sm font-bold text-accent">
        {copied === 'link' ? t.copied : copied === 'message' ? t.messageCopied : ''}
      </p>
      <p className="text-sm text-muted">{t.expires(expires)}</p>
      <p className="mt-3 rounded-lg bg-warn-box px-3 py-2 text-sm font-bold">{t.onceWarning}</p>
    </section>
  )
}
