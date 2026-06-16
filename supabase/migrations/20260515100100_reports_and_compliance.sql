-- =====================================================================
-- Reports + compliance hardening (15/05/2026)
--
-- Aggiunge:
--  - tabella public.reports per le segnalazioni utenti (UGC moderation,
--    richiesto da Apple App Store Guideline 1.2)
--  - trigger che impedisce ai client di scrivere direttamente le colonne
--    di entitlement (pro_expires_at / boost_expires_at): l'aggiornamento
--    di queste colonne deve passare dall'Edge Function `validate-iap-receipt`
--    che usa service_role e ha appena verificato il JWS Apple.
--
-- Sicuro da rilanciare (IF EXISTS / IF NOT EXISTS).
-- =====================================================================

-- 1) Tabella reports ----------------------------------------------------

create table if not exists public.reports (
    id              uuid        primary key default gen_random_uuid(),
    reporter_id     uuid        not null references public.profiles(id) on delete cascade,

    -- target_type indica cosa è stato segnalato
    --   'user'           → un utente (target_id = profiles.id)
    --   'review'         → una recensione (target_id = reviews.id)
    --   'message'        → un messaggio (target_id = messages.id)
    --   'portfolio_item' → una foto del portfolio (target_id = portfolio_items.id)
    --   'offer'          → un'offerta servizio (target_id = service_offers.id)
    target_type     text        not null check (target_type in (
        'user', 'review', 'message', 'portfolio_item', 'offer'
    )),
    target_id       uuid        not null,

    -- Motivo predefinito scelto dall'utente
    --   'spam', 'inappropriate', 'harassment', 'fake', 'impersonation',
    --   'illegal', 'other'
    reason          text        not null check (reason in (
        'spam', 'inappropriate', 'harassment', 'fake',
        'impersonation', 'illegal', 'other'
    )),

    -- Descrizione libera opzionale (max 1000 char)
    description     text,

    -- Stato della moderazione
    --   'pending' → segnalazione appena ricevuta, in attesa di review
    --   'reviewed' → letta dal team ma non ancora actioned
    --   'actioned' → presa azione (utente sospeso, contenuto rimosso…)
    --   'dismissed' → segnalazione respinta dopo review
    status          text        not null default 'pending'
                    check (status in ('pending', 'reviewed', 'actioned', 'dismissed')),

    -- Note interne dei moderatori (NON visibili al reporter)
    moderator_notes text,

    created_at      timestamptz not null default now(),
    reviewed_at     timestamptz,

    -- Un utente non può segnalare lo stesso target due volte (deduplica).
    unique (reporter_id, target_type, target_id)
);

create index if not exists reports_status_created_idx
    on public.reports(status, created_at desc)
    where status = 'pending';

create index if not exists reports_target_idx
    on public.reports(target_type, target_id);

alter table public.reports enable row level security;

-- INSERT: chiunque sia authenticated può segnalare, ma il reporter_id
-- deve coincidere con auth.uid() (no spoofing).
drop policy if exists "rep_insert_own" on public.reports;
create policy "rep_insert_own" on public.reports
    for insert to authenticated
    with check (auth.uid() = reporter_id);

-- SELECT: l'utente vede solo le proprie segnalazioni (lo storico personale).
-- I moderatori usano service_role e bypassano RLS.
drop policy if exists "rep_select_own" on public.reports;
create policy "rep_select_own" on public.reports
    for select to authenticated
    using (auth.uid() = reporter_id);

-- Nessun UPDATE/DELETE dal client: solo i moderatori (service_role)
-- possono cambiare status, aggiungere note, ecc.

comment on table public.reports is
    'Segnalazioni utente di contenuti/utenti per moderazione UGC. '
    'Richiesto da Apple App Store Guideline 1.2. SLA risposta entro 24h.';


-- 2) Hardening profiles: trigger che blocca client su entitlement -----
--
-- La policy UPDATE attuale di profiles probabilmente è
-- "auth.uid() = id" che permette di scrivere TUTTE le colonne.
-- Aggiungiamo un BEFORE UPDATE trigger che, se la query NON proviene
-- da service_role, RIFIUTA modifiche a pro_expires_at e boost_expires_at.

create or replace function public.profiles_block_client_entitlement_update()
returns trigger
language plpgsql
security definer
as $$
begin
    -- service_role / postgres bypassano questo check.
    -- auth.role() restituisce 'service_role' se la richiesta usa la chiave
    -- service. Per i client (anon, authenticated) restituisce 'authenticated' o 'anon'.
    if auth.role() = 'service_role' then
        return new;
    end if;

    if new.pro_expires_at is distinct from old.pro_expires_at then
        raise exception
            'profiles.pro_expires_at can only be updated by validate-iap-receipt edge function (service_role required)'
            using errcode = '42501';  -- insufficient_privilege
    end if;

    if new.boost_expires_at is distinct from old.boost_expires_at then
        raise exception
            'profiles.boost_expires_at can only be updated by validate-iap-receipt edge function (service_role required)'
            using errcode = '42501';
    end if;

    return new;
end;
$$;

drop trigger if exists profiles_block_entitlement_update on public.profiles;
create trigger profiles_block_entitlement_update
    before update on public.profiles
    for each row
    execute function public.profiles_block_client_entitlement_update();

comment on function public.profiles_block_client_entitlement_update() is
    'Impedisce ai client (anon/authenticated) di modificare le colonne '
    'di entitlement IAP. Solo l''edge function validate-iap-receipt '
    'tramite service_role può scriverle dopo aver verificato il JWS Apple.';


-- 3) Trigger di consistenza is_pro = (pro_expires_at > now()) ---------
--
-- Il campo profiles.is_pro è una boolean comoda per query/UI. Va mantenuto
-- in sync con pro_expires_at: lo facciamo lato server in modo che non possa
-- divergere (es. client malevolo che imposta is_pro = true).

create or replace function public.profiles_sync_is_pro()
returns trigger
language plpgsql
as $$
begin
    new.is_pro := (new.pro_expires_at is not null and new.pro_expires_at > now());
    return new;
end;
$$;

drop trigger if exists profiles_sync_is_pro_trigger on public.profiles;
create trigger profiles_sync_is_pro_trigger
    before insert or update of pro_expires_at on public.profiles
    for each row
    execute function public.profiles_sync_is_pro();
