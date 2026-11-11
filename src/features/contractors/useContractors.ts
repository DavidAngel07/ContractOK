import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'

export type ContractorRow = {
  id: string
  kind: 'natural' | 'company'
  display_name: string
  email: string
  status: string
  created_at: string
}

// Lista de contratistas activos (no archivados). La comparten el dashboard y la lista.
export function useContractors() {
  return useQuery({
    queryKey: ['contractors'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('contractors')
        .select('id, kind, display_name, email, status, created_at')
        .is('archived_at', null)
        .order('created_at', { ascending: false })
      if (error) throw error
      return (data ?? []) as ContractorRow[]
    },
  })
}
