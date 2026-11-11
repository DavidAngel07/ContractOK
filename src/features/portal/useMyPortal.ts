import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../auth/AuthProvider'

export type PortalRow = {
  contractor_id: string
  display_name: string
  kind: 'natural' | 'company'
  status: string
  company_id: string
  company_name: string
}

// Contratistas a los que el usuario autenticado tiene acceso como contratista.
export function useMyPortal() {
  const { session } = useAuth()
  const userId = session?.user.id
  return useQuery({
    queryKey: ['my-portal', userId],
    enabled: Boolean(userId),
    queryFn: async () => {
      const { data, error } = await supabase.rpc('my_contractor_portal')
      if (error) throw error
      return (data ?? []) as PortalRow[]
    },
  })
}
