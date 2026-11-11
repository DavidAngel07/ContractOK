// El contratista puede editar sus datos solo en estos estados (misma regla que la base de datos).
export const PROFILE_EDITABLE = ['invited', 'filling', 'observations']

export function profileComplete(c: { legal_name: string | null; tax_id: string | null } | null | undefined) {
  return Boolean(c?.legal_name?.trim() && c?.tax_id?.trim())
}
