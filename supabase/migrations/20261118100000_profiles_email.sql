-- ContractOK · Semana 3 · Parte 2 · Correo en el perfil
-- La lista de usuarios de la empresa necesita mostrar el correo, que hoy solo está en Auth (no legible desde la app).
-- Se copia al perfil, que ya tiene reglas de visibilidad (uno mismo y quienes comparten empresa).

alter table public.profiles add column email text;

update public.profiles p set email = lower(u.email) from auth.users u where u.id = p.id;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(coalesce(new.email, ''), '@', 1)),
    lower(new.email)
  );
  return new;
end $$;

-- Si el correo cambia en Auth, el perfil lo sigue.
create or replace function public.handle_user_email_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.profiles set email = lower(new.email) where id = new.id;
  return new;
end $$;

create trigger on_auth_user_email_changed after update of email on auth.users
  for each row when (old.email is distinct from new.email)
  execute function public.handle_user_email_change();

revoke execute on function public.handle_user_email_change() from public, anon, authenticated;

-- Cada persona solo puede editar sus datos personales, no su correo ni su id.
revoke update on public.profiles from authenticated;
grant update (full_name, job_title, phone, avatar_path, ui_preferences) on public.profiles to authenticated;
