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
import { CompanyPage } from './features/settings/CompanyPage'
import { DocumentFormPage } from './features/settings/DocumentFormPage'
import { DocumentsPage } from './features/settings/DocumentsPage'
import { Gate } from './features/settings/Gate'
import { ProfileEditorPage } from './features/settings/ProfileEditorPage'
import { ProfilesPage } from './features/settings/ProfilesPage'
import { RolesPage } from './features/settings/RolesPage'
import { SettingsIndex, SettingsLayout } from './features/settings/SettingsLayout'
import { UsersPage } from './features/settings/UsersPage'
import { SetupPage } from './features/setup/SetupPage'

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
          <Route element={<Gate permission="company.configure" />}>
            <Route path="/setup" element={<SetupPage />} />
          </Route>
          <Route element={<AppLayout />}>
            <Route path="/dashboard" element={<HomePage />} />
            <Route path="/contractors" element={<ContractorsPage />} />
            <Route path="/contractors/new" element={<NewContractorPage />} />
            <Route path="/contractors/:id" element={<ContractorDetailPage />} />
            <Route path="/settings" element={<SettingsLayout />}>
              <Route index element={<SettingsIndex />} />
              <Route element={<Gate permission="company.configure" />}>
                <Route path="company" element={<CompanyPage />} />
                <Route path="documents" element={<DocumentsPage />} />
                <Route path="documents/new" element={<DocumentFormPage />} />
                <Route path="documents/:id" element={<DocumentFormPage />} />
                <Route path="profiles" element={<ProfilesPage />} />
                <Route path="profiles/new" element={<ProfileEditorPage />} />
                <Route path="profiles/:id" element={<ProfileEditorPage />} />
              </Route>
              <Route element={<Gate permission="users.manage" />}>
                <Route path="roles" element={<RolesPage />} />
                <Route path="users" element={<UsersPage />} />
              </Route>
            </Route>
          </Route>
        </Route>
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
