-- =====================================================================
-- Scadenza dell'abbonamento Pro e limiti del piano gratuito.
--
-- Due buchi che si chiudono insieme, perche' parlano dello stesso patto
-- con l'utente: cosa hai pagato, e cosa ottieni senza pagare.
--
-- 1) `profiles.is_pro` non decadeva mai.
--    Il trigger `profiles_sync_is_pro_trigger` (20260515100100) ricalcola
--    il flag solo `before insert or update of pro_expires_at`. Quando un
--    abbonamento scade, pero', Apple non manda piu' niente: la app non
--    chiama `validate-iap-receipt`, nessuno riscrive la riga e `is_pro`
--    resta acceso per sempre. Un mese pagato valeva a vita.
--
-- 2) I limiti del piano gratuito vivevano solo nell'app iOS.
--    Nessuna policy e nessun trigger li imponeva: bastava parlare con
--    l'API per pubblicare offerte illimitate senza abbonarsi.
-- =====================================================================


-- 1) Chi e' Pro adesso -------------------------------------------------
--
-- La data comanda, non il flag: e' la stessa regola che l'app applica
-- lato client su `Profile.isPro`.

create or replace function public.brindoo_is_pro(target_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(p.pro_expires_at > now(), false)
      from public.profiles p
     where p.id = target_id;
$$;

comment on function public.brindoo_is_pro(uuid) is
    'True se l''abbonamento Pro dell''utente e'' attivo in questo momento. '
    'Guarda pro_expires_at, non il flag is_pro, che e'' solo una cache.';


-- 2) Spegnere gli abbonamenti scaduti ----------------------------------
--
-- Tocca solo `is_pro`: `pro_expires_at` resta lo storico di quando
-- l'abbonamento e' finito, e resta protetto dal trigger che riserva la
-- colonna alla edge function.

create or replace function public.brindoo_expire_pro()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    expired_count integer;
begin
    update public.profiles
       set is_pro = false
     where is_pro
       and coalesce(pro_expires_at, to_timestamp(0)) <= now();

    get diagnostics expired_count = row_count;
    return expired_count;
end;
$$;

comment on function public.brindoo_expire_pro() is
    'Spegne is_pro sui profili con abbonamento scaduto. Invocabile a mano '
    'o via pg_cron: senza questa passata il flag resterebbe acceso per sempre.';

-- Una passata subito, per le righe gia' scadute in produzione.
select public.brindoo_expire_pro();

-- Poi ogni ora, se pg_cron c'e'. Un'ora di ritardo sulla scadenza e'
-- accettabile; l'app intanto ricalcola gia' da sola lato dispositivo.
do $$
begin
    if exists (select 1 from pg_extension where extname = 'pg_cron') then
        perform cron.unschedule('brindoo_expire_pro')
            from cron.job
            where jobname = 'brindoo_expire_pro';

        perform cron.schedule(
            'brindoo_expire_pro',
            '0 * * * *',
            $cron$select public.brindoo_expire_pro();$cron$
        );
    end if;
end$$;


-- 3) Limite offerte attive del piano gratuito --------------------------
--
-- Le righe gia' esistenti non vengono toccate: chi era Pro e lascia
-- scadere l'abbonamento tiene le offerte che ha gia' pubblicato, ma non
-- puo' pubblicarne o riattivarne altre finche' non torna sotto il tetto.

create or replace function public.brindoo_enforce_offer_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    active_count integer;
begin
    if new.status is distinct from 'active' then
        return new;
    end if;

    if coalesce(public.brindoo_is_pro(new.organizer_id), false) then
        return new;
    end if;

    select count(*) into active_count
      from public.service_offers o
     where o.organizer_id = new.organizer_id
       and o.status = 'active'
       and o.id is distinct from new.id;

    if active_count >= 1 then
        raise exception
            'Il piano gratuito permette 1 offerta attiva: passa a Brindoo Pro per averne quante vuoi'
            using errcode = '42501';
    end if;

    return new;
end;
$$;

drop trigger if exists service_offers_enforce_free_limit on public.service_offers;
create trigger service_offers_enforce_free_limit
    before insert or update of status on public.service_offers
    for each row
    execute function public.brindoo_enforce_offer_limit();


-- 4) Limite richieste aperte del piano gratuito ------------------------
--
-- Il primo vantaggio Pro pensato per i clienti. Il tetto vive qui e in
-- `ClientRequestService.maxOpenRequestsFree`: se cambia uno, cambia l'altro.

create or replace function public.brindoo_enforce_client_request_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    open_count integer;
    max_free   constant integer := 2;
begin
    if new.status is distinct from 'open' then
        return new;
    end if;

    if coalesce(public.brindoo_is_pro(new.client_id), false) then
        return new;
    end if;

    select count(*) into open_count
      from public.client_requests r
     where r.client_id = new.client_id
       and r.status = 'open'
       and r.id is distinct from new.id;

    if open_count >= max_free then
        raise exception
            'Il piano gratuito permette % richieste aperte: passa a Brindoo Pro per averne quante vuoi', max_free
            using errcode = '42501';
    end if;

    return new;
end;
$$;

drop trigger if exists client_requests_enforce_free_limit on public.client_requests;
create trigger client_requests_enforce_free_limit
    before insert or update of status on public.client_requests
    for each row
    execute function public.brindoo_enforce_client_request_limit();
