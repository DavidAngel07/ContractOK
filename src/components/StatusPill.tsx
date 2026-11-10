import type { Tone } from '../features/contractors/utils'

export function StatusPill({ tone, children }: { tone: Tone; children: string }) {
  return <span className={`pill pill-${tone}`}>{children}</span>
}
