import { Link, Navigate, useNavigate } from 'react-router-dom'
import { es } from '../../i18n/es'
import { Logo } from '../../components/Logo'
import { OtpForm } from '../invite/OtpForm'
import { useAuth } from './AuthProvider'

export function ContractorLoginPage() {
  const { session, loading } = useAuth()
  const navigate = useNavigate()
  if (!loading && session) return <Navigate to="/" replace />

  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <div className="w-full max-w-md">
        <div className="mb-8">
          <Logo />
        </div>
        <div className="card p-8">
          <h1 className="text-3xl font-extrabold tracking-tight">{es.contractorLogin.title}</h1>
          <p className="mt-1 mb-6 text-muted">{es.contractorLogin.subtitle}</p>
          <OtpForm shouldCreateUser={false} onVerified={() => navigate('/', { replace: true })} />
        </div>
        <p className="mt-6 text-center text-sm">
          <Link to="/login" className="font-bold text-link underline">
            {es.contractorLogin.staffLink}
          </Link>
        </p>
      </div>
    </main>
  )
}
