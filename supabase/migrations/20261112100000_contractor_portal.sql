-- ContractOK · Semana 2 · Parte 3 · Portal del contratista
-- El contratista completa su ficha mediante una función (no con UPDATE directo a la tabla),
-- así solo puede cambiar sus datos de contacto y solo mientras su registro está en diligenciamiento.

create or replace function public.contractor_update_profile(
  p_contractor_id uuid, p_legal_name text, p_tax_id text, p_phone text
)
returns void language plpgsql security definer set search_path = '' as $$
declare v_status text;
begin
  if not public.is_contractor_member(p_contractor_id) then
    raise exception 'No tienes acceso a este contratista' using errcode = '42501';
  end if;
  select c.status into v_status from public.contractors c
  where c.id = p_contractor_id and c.archived_at is null;
  if v_status is null then
    raise exception 'Contratista no encontrado' using errcode = 'P0002';
  end if;
  if v_status not in ('invited', 'filling', 'observations') then
    raise exception 'Tus datos ya no se pueden modificar. Contacta a la empresa.' using errcode = '42501';
  end if;

  update public.contractors set
    legal_name = nullif(trim(p_legal_name), ''),
    tax_id = nullif(trim(p_tax_id), ''),
    phone = nullif(trim(p_phone), '')
  where id = p_contractor_id;
end $$;

revoke execute on function public.contractor_update_profile(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.contractor_update_profile(uuid, text, text, text) to authenticated;
