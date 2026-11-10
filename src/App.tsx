import { Navigate, Route, Routes } from 'react-router-dom'
import { AppLayout } from './components/AppLayout'
import { HomePage } from './features/account/HomePage'
import { LoginPage } from './features/auth/LoginPage'
import { RequireAuth } from './features/auth/RequireAuth'
import { ContractorDetailPage } from './features/contractors/ContractorDetailPage'
import { ContractorsPage } from './features/contractors/ContractorsPage'
import { NewContractorPage } from './features/contractors/NewContractorPage'
import { InvitePage } from './features/invite/InvitePage'

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/invite/:token" element={<InvitePage />} />
      <Route element={<RequireAuth />}>
        <Route element={<AppLayout />}>
          <Route path="/" element={<HomePage />} />
          <Route path="/contractors" element={<ContractorsPage />} />
          <Route path="/contractors/new" element={<NewContractorPage />} />
          <Route path="/contractors/:id" element={<ContractorDetailPage />} />
        </Route>
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
