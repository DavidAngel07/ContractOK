import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import './styles.css'
import App from './App'
import { AuthProvider } from './features/auth/AuthProvider'
import { isSupabaseConfigured } from './lib/supabase'
import { es } from './i18n/es'

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: 1, refetchOnWindowFocus: false } },
})

const root = createRoot(document.getElementById('root')!)

if (!isSupabaseConfigured) {
  root.render(
    <main className="mx-auto max-w-xl p-8">
      <h1 className="text-2xl font-bold">{es.configMissing.title}</h1>
      <p className="mt-3 text-muted">{es.configMissing.body}</p>
    </main>,
  )
} else {
  root.render(
    <StrictMode>
      <QueryClientProvider client={queryClient}>
        <BrowserRouter>
          <AuthProvider>
            <App />
          </AuthProvider>
        </BrowserRouter>
      </QueryClientProvider>
    </StrictMode>,
  )
}
