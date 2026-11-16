import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { one } from '../../lib/utils'
import { useAuth } from '../auth/AuthProvider'

export type Scope = 'all' | 'assigned'
export type SetupStatus = 'not_started' | 'in_progress' | 'completed'
export type Account = {
  companyId: string
  companyName: string
  setupStatus: SetupStatus
  setupStep: number
  roleName: string
  permissions: Map<string, Scope>
}

type CompanyBits = { name: string; setup_status: SetupStatus; setup_step: number }
type Raw = {
  company_id: string
  company: CompanyBits | CompanyBits[] | null
  role:
    | { name: string; role_permissions: { permission_key: string; scope: Scope }[] }
    | { name: string; role_permissions: { permission_key: string; scope: Scope }[] }[]
    | null
}

// Empresa activa del usuario y sus responsabilidades. (MVP: una empresa por usuario.)
export function useAccount() {
  const { session } = useAuth()
  const userId = session?.user.id

  const query = useQuery({
    queryKey: ['account-context', userId],
    enabled: Boolean(userId),
    queryFn: async (): Promise<Account | null> => {
      const { data, error } = await supabase
        .from('memberships')
        .select('company_id, company:companies(name, setup_status, setup_step), role:roles(name, role_permissions(permission_key, scope))')
        .eq('user_id', userId!)
        .eq('status', 'active')
        .limit(1)
      if (error) throw error
      const row = (data?.[0] ?? null) as unknown as Raw | null
      if (!row) return null
      const role = one(row.role)
      const company = one(row.company)
      return {
        companyId: row.company_id,
        companyName: company?.name ?? '',
        setupStatus: company?.setup_status ?? 'completed',
        setupStep: company?.setup_step ?? 0,
        roleName: role?.name ?? '',
        permissions: new Map((role?.role_permissions ?? []).map((p) => [p.permission_key, p.scope])),
      }
    },
  })

  const account = query.data ?? null
  return {
    account,
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    error: query.error,
    can: (permission: string) => account?.permissions.has(permission) ?? false,
  }
}
