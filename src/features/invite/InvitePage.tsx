import { es } from '../../i18n/es'

// Marcador de posición: el portal del contratista se construye en la parte 3 de la semana 2.
export function InvitePage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col justify-center gap-3 p-6">
      <p className="text-2xl font-extrabold tracking-tight">
        Contract<span className="text-accent">OK</span>
      </p>
      <h1 className="text-2xl font-bold">{es.invite.title}</h1>
      <p className="text-muted">{es.invite.body}</p>
    </main>
  )
}
