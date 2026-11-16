import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'

export type DocType = {
  id: string
  name: string
  description: string | null
  instructions: string | null
  owner_kind: 'contractor' | 'worker'
  scope: 'contractor' | 'contract'
  phase: 'contracting' | 'monthly' | 'sst' | 'closing'
  periodicity: 'once' | 'expiring' | 'monthly' | 'closing'
  requires_dates: boolean
  max_age_days: number | null
  retention_years: number
  alert_category: 'operational' | 'compliance'
  alert_audience: string[]
  is_active: boolean
  sort_order: number
}

export const PHASES = ['contracting', 'monthly', 'sst', 'closing'] as const

const DOC_COLUMNS =
  'id, name, description, instructions, owner_kind, scope, phase, periodicity, requires_dates, max_age_days, retention_years, alert_category, alert_audience, is_active, sort_order'

export function useDocumentTypes() {
  return useQuery({
    queryKey: ['document-types'],
    queryFn: async () => {
      const { data, error } = await supabase.from('document_types').select(DOC_COLUMNS).order('sort_order').order('name')
      if (error) throw error
      return (data ?? []) as DocType[]
    },
  })
}

export type ProfileRow = {
  id: string
  name: string
  description: string | null
  contractor_kind: 'natural' | 'company' | 'both'
  is_active: boolean
  items: { count: number }[] | null
}

export function useProfiles() {
  return useQuery({
    queryKey: ['profiles'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('requirement_profiles')
        .select('id, name, description, contractor_kind, is_active, items:requirement_profile_items(count)')
        .order('name')
      if (error) throw error
      return (data ?? []) as unknown as ProfileRow[]
    },
  })
}

export type PermissionRow = { key: string; description: string }

export function usePermissionCatalog() {
  return useQuery({
    queryKey: ['permission-catalog'],
    staleTime: Infinity,
    queryFn: async () => {
      const { data, error } = await supabase.from('permissions').select('key, description').order('key')
      if (error) throw error
      return (data ?? []) as PermissionRow[]
    },
  })
}

// Mensajes de error comunes de la base de datos.
export type DbError = { code?: string; message?: string }
