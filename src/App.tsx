import { Navigate, Route, Routes } from 'react-router-dom'
import { AppLayout } from './components/AppLayout'
import { HomePage } from './features/account/HomePage'
import { ContractorLoginPage } from './features/auth/ContractorLoginPage'
import { EntryRedirect, RequireContractor, RequireStaff } from './features/auth/EntryRedirect'
import { LoginPage } from './features/auth/LoginPage'
import { RequireAuth } from './features/auth/RequireAuth'
import { ContractorDetailPage } from './features/contractors/ContractorDetailPage'
import { ContractorsPage } from './features/contractors/ContractorsPage'
import { NewContractorPage } from './features/contractors/NewContractorPage'
import { InvitePage } from './features/invite/InvitePage'
import { PortalLayout } from './features/portal/PortalLayout'
import { PortalPage } from './features/portal/PortalPage'

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/ingreso" element={<ContractorLoginPage />} />
      <Route path="/invite/:token" element={<InvitePage />} />
      <Route element={<RequireAuth />}>
        <Route path="/" element={<EntryRedirect />} />
        <Route element={<RequireContractor />}>
          <Route element={<PortalLayout />}>
            <Route path="/portal" element={<PortalPage />} />
          </Route>
        </Route>
        <Route element={<RequireStaff />}>
          <Route element={<AppLayout />}>
            <Route path="/dashboard" element={<HomePage />} />
            <Route path="/contractors" element={<ContractorsPage />} />
            <Route path="/contractors/new" element={<NewContractorPage />} />
            <Route path="/contractors/:id" element={<ContractorDetailPage />} />
          </Route>
        </Route>
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
