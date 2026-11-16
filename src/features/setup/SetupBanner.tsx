import { Link } from 'react-router-dom'
import { es } from '../../i18n/es'
import { useAccount } from '../account/useAccount'

// Aviso del dashboard: solo para quien puede configurar la empresa, mientras la configuración inicial no esté terminada.
export function SetupBanner() {
  const { account, can } = useAccount()
  if (!account || !can('company.configure') || account.setupStatus === 'completed') return null
  const step = Math.max(account.setupStep, 1)
  return (
    <section className="card flex flex-wrap items-center justify-between gap-4 border-accent p-5" aria-labelledby="setup-banner">
      <div>
        <h2 id="setup-banner" className="text-lg font-bold">{es.setup.banner.title}</h2>
        <p className="text-muted">{es.setup.banner.body(step, 6)}</p>
      </div>
      <Link to={`/setup?step=${step}`} className="btn btn-primary">{es.setup.banner.cta}</Link>
    </section>
  )
}
