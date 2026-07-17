-- Decimo giro (parte 2): FAQ sul profilo professionista + badge identità verificata.
--
-- faqs: elenco di massimo 5 coppie domanda/risposta scritte dal professionista,
--   mostrate ai clienti sul profilo per ridurre le chat ripetitive.
-- identity_verified: assegnato SOLO dall'amministrazione (dashboard/service role);
--   un trigger blocca i tentativi di auto-assegnazione via API.

alter table public.profiles
  add column if not exists faqs jsonb not null default '[]'::jsonb,
  add column if not exists identity_verified boolean not null default false;

alter table public.profiles
  add constraint profiles_faqs_is_array
  check (jsonb_typeof(faqs) = 'array' and jsonb_array_length(faqs) <= 5);

-- Blocca la modifica di identity_verified da parte degli utenti loggati via API.
-- auth.uid() è NULL per il service role e per le query dirette da dashboard,
-- che restano quindi libere di assegnare o togliere il badge.
create or replace function public.protect_identity_verified()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.identity_verified is distinct from old.identity_verified
     and auth.uid() is not null then
    raise exception 'identity_verified puo'' essere modificato solo dall''amministrazione';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_identity_verified on public.profiles;
create trigger trg_protect_identity_verified
  before update on public.profiles
  for each row execute function public.protect_identity_verified();
