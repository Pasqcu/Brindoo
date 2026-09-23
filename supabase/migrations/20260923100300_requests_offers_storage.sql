-- =====================================================================
-- Richieste scadute, vetrina offerte, file privati della chat.
--
-- 1) Il lavoro notturno `auto_close_expired_requests` chiudeva le righe di
--    `public.requests`, tabella che non esiste piu': falliva ogni notte e
--    le richieste con la data passata restavano aperte, visibili ai
--    professionisti e conteggiate nel limite del piano gratuito.
-- 2) Le offerte si ordinavano (Boost > Pro) e si filtravano per categoria
--    DOPO aver preso le 100 piu' recenti: con piu' offerte, quelle dei Pro
--    piu' vecchie sparivano. Stessa correzione gia' fatta per profili e
--    richieste (20260829120000). La vista dice anche chi e' in vacanza.
-- 3) Modalita' vacanza: `vacation_until` e' il giorno in cui si torna
--    disponibili. In vacanza = oggi < vacation_until.
-- 4) Storage: il bucket `chat-images` era pubblico (foto e vocali privati
--    apribili da chiunque con il link) e le policy di caricamento di
--    `portfolio` e `avatars` accettavano qualunque cartella.
-- =====================================================================


-- 1) Richieste con la data passata -----------------------------------------------

create or replace function public.auto_close_expired_requests()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    closed_count integer;
begin
    update public.client_requests
       set status = 'closed'
     where status = 'open'
       and event_date is not null
       and event_date < public.brindoo_rome_today();
    get diagnostics closed_count = row_count;
    return closed_count;
end;
$$;

revoke all on function public.auto_close_expired_requests() from public, anon, authenticated;

-- Subito, e poi ogni notte (il job esiste gia' con questo comando).
select public.auto_close_expired_requests();

create or replace function public.brindoo_enforce_client_request_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    open_count integer;
    max_free   constant integer := 2;
    v_today    date := public.brindoo_rome_today();
begin
    if new.status is distinct from 'open' then
        return new;
    end if;

    -- Una richiesta per un giorno gia' passato non si apre: si chiude da sola.
    if new.event_date is not null and new.event_date < v_today then
        raise exception 'La data di questa richiesta e'' gia'' passata: pubblicane una nuova'
            using errcode = '22023';
    end if;

    if coalesce(public.brindoo_is_pro(new.client_id), false) then
        return new;
    end if;

    select count(*) into open_count
      from public.client_requests r
     where r.client_id = new.client_id
       and r.status = 'open'
       and (r.event_date is null or r.event_date >= v_today)
       and r.id is distinct from new.id;

    if open_count >= max_free then
        raise exception
            'Il piano gratuito permette % richieste aperte: passa a Brindoo Pro per averne quante vuoi', max_free
            using errcode = '42501';
    end if;

    return new;
end;
$$;


-- 2) Vetrina offerte ordinata dal database ------------------------------------------

drop view if exists public.service_offers_ranked;
create view public.service_offers_ranked
with (security_invoker = true)
as
    select o.*,
           coalesce(p.boost_expires_at > now(), false) as boost_active,
           coalesce(p.pro_expires_at  > now(), false) as pro_active,
           coalesce(p.vacation_until > (now() at time zone 'Europe/Rome')::date, false)
               as organizer_on_vacation
      from public.service_offers o
      join public.profiles p on p.id = o.organizer_id;

comment on view public.service_offers_ranked is
    'service_offers + boost_active/pro_active/organizer_on_vacation calcolati adesso: '
    'ordine e filtri decisi prima di tagliare la pagina.';

revoke all on public.service_offers_ranked from anon;
grant select on public.service_offers_ranked to authenticated;


-- 3) File privati della chat -----------------------------------------------------------

update storage.buckets set public = false where id = 'chat-images';

drop policy if exists "All can view chat-images" on storage.objects;
drop policy if exists "Partecipanti vedono i file della chat" on storage.objects;
create policy "Partecipanti vedono i file della chat" on storage.objects
    for select to authenticated
    using (
        bucket_id = 'chat-images'
        and (
            lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
            or exists (
                select 1 from public.conversations c
                 where (c.client_id = auth.uid()
                        and lower(c.organizer_id::text) = lower((storage.foldername(name))[1]))
                    or (c.organizer_id = auth.uid()
                        and lower(c.client_id::text) = lower((storage.foldername(name))[1]))
            )
        )
    );


-- 4) Caricamenti solo nella propria cartella -------------------------------------------
--
-- L'app scrive le cartelle con l'UUID maiuscolo (`uuidString`), auth.uid()
-- e' minuscolo: le policy "per cartella" non scattavano mai e reggevano
-- tutto quelle larghe, che accettavano qualunque percorso.

drop policy if exists "Auth upload portfolio ijvnt4_0" on storage.objects;
drop policy if exists "Auth upload avatars 1oj01fe_0" on storage.objects;

drop policy if exists "Organizzatore carica nel proprio portfolio" on storage.objects;
create policy "Organizzatore carica nel proprio portfolio" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'portfolio'
                and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));

drop policy if exists "Organizzatore cancella le proprie foto portfolio" on storage.objects;
create policy "Organizzatore cancella le proprie foto portfolio" on storage.objects
    for delete to authenticated
    using (bucket_id = 'portfolio'
           and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));

drop policy if exists "Utente carica il proprio avatar" on storage.objects;
create policy "Utente carica il proprio avatar" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'avatars'
                and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));

drop policy if exists "Utente aggiorna il proprio avatar" on storage.objects;
create policy "Utente aggiorna il proprio avatar" on storage.objects
    for update to authenticated
    using (bucket_id = 'avatars'
           and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));

drop policy if exists "Utente cancella il proprio avatar" on storage.objects;
create policy "Utente cancella il proprio avatar" on storage.objects
    for delete to authenticated
    using (bucket_id = 'avatars'
           and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));

do $$
begin
    if (select public from storage.buckets where id = 'chat-images') then
        raise exception 'chat-images e'' ancora pubblico';
    end if;
    raise notice 'OK: richieste scadute, vetrina offerte e storage sistemati.';
end$$;
