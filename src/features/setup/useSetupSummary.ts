import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAccount } from '../account/useAccount'
import { useDocumentTypes, useProfiles } from '../settings/hooks'

export type Blocker = { text: string; step: number }

// Resumen de la configuración para la revisión final.
export function useSetupSummary(texts: {
  noDocuments: string
  noProfiles: string
}) {
  const { account } = useAccount()
  const docs = useDocumentTypes()
  const profiles = useProfiles()
  const counts = useQuery({
    queryKey: ['setup-counts', account?.companyId],
    enabled: Boolean(account?.companyId),
    queryFn: async () => {
      const [r, m, p] = await Promise.all([
        supabase.from('roles').select('id', { count: 'exact', head: true }),
        supabase.from('memberships').select('id', { count: 'exact', head: true }).eq('status', 'active'),
        supabase.from('staff_invitations').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
      ])
      if (r.error) throw r.error
      if (m.error) throw m.error
      return { roles: r.count ?? 0, members: m.count ?? 0, pending: p.count ?? 0 }
    },
  })

  const activeDocs = (docs.data ?? []).filter((d) => d.is_active).length
  const activeProfiles = (profiles.data ?? []).filter((p) => p.is_active)
  const withItems = activeProfiles.filter((p) => (p.items?.[0]?.count ?? 0) > 0)
  const emptyProfiles = activeProfiles.filter((p) => (p.items?.[0]?.count ?? 0) === 0)

  const blockers: Blocker[] = []
  if (activeDocs === 0) blockers.push({ text: texts.noDocuments, step: 2 })
  if (withItems.length === 0) blockers.push({ text: texts.noProfiles, step: 3 })

  return {
    isLoading: docs.isLoading || profiles.isLoading || counts.isLoading,
    activeDocs,
    activeProfiles: activeProfiles.length,
    profilesWithItems: withItems.length,
    emptyProfiles,
    roles: counts.data?.roles ?? 0,
    members: counts.data?.members ?? 0,
    pending: counts.data?.pending ?? 0,
    blockers,
  }
}
