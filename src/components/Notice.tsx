import type { ReactNode } from 'react'

// Mensaje de éxito o de error, anunciado por lectores de pantalla.
export function Notice({ kind, children }: { kind: 'ok' | 'error' | 'info'; children: ReactNode }) {
  const style =
    kind === 'ok' ? 'bg-ok-box text-ok-ink' : kind === 'error' ? 'bg-danger-bg text-danger' : 'bg-warn-box text-ink'
  return (
    <p role={kind === 'error' ? 'alert' : 'status'} className={`rounded-xl px-3 py-2 text-sm font-bold ${style}`}>
      {children}
    </p>
  )
}
