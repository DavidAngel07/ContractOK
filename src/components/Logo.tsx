import { es } from '../i18n/es'

// Ícono oficial de la marca + nombre «contractOK» en Plus Jakarta Sans.
export function Logo({ onDark = false, size = 40 }: { onDark?: boolean; size?: number }) {
  return (
    <span className="inline-flex items-center gap-2.5">
      <img src="/brand/logo-mark.png" alt="" width={size} height={size} style={{ width: size, height: size }} />
      <span className="text-[1.35rem] leading-none tracking-tight" style={{ color: onDark ? '#ffffff' : 'var(--ink)' }}>
        <span className="font-medium">contract</span>
        <span className="font-extrabold" style={{ color: onDark ? '#C4B5FD' : 'var(--accent)' }}>OK</span>
        <span className="sr-only"> — {es.brand.tagline}</span>
      </span>
    </span>
  )
}
