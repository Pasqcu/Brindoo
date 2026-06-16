-- =====================================================================
-- Brindoo: passaggio a PREZZO SINGOLO + sistema di TRATTATIVA stile Vinted.
--
-- 1) requests:        budget_min/budget_max  → budget (numeric, nullable)
-- 2) service_offers:  price_from/price_to    → price  (numeric, NOT NULL)
-- 3) offer_proposals      : negoziazione attiva per (offer, client)
-- 4) offer_proposal_rounds: cronologia minima (proposta corrente + ultima controproposta)
-- 5) offer_dismissals     : offerte "nascoste" dal cliente
-- 6) auto-archive richieste con event_date passata: passano a 'closed'
-- =====================================================================

-- ------------------ 1) requests.budget -------------------------------

alter table public.requests
    add column if not exists budget numeric;

-- Migrazione dati: usa la media se entrambi presenti, altrimenti il valore disponibile.
update public.requests
set budget = coalesce(
    budget,
    case
        when budget_min is not null and budget_max is not null then (budget_min + budget_max) / 2
        when budget_min is not null then budget_min
        when budget_max is not null then budget_max
        else null
    end
)
where budget is null;

alter table public.requests drop column if exists budget_min;
alter table public.requests drop column if exists budget_max;

-- ------------------ 2) service_offers.price --------------------------

alter table public.service_offers
    add column if not exists price numeric;

update public.service_offers
set price = coalesce(
    price,
    case
        when price_from is not null and price_to is not null then (price_from + price_to) / 2
        when price_from is not null then price_from
        when price_to is not null then price_to
        else 0
    end
)
where price is null;

-- Ora che ogni riga ha un prezzo, rendiamo la colonna NOT NULL.
alter table public.service_offers
    alter column price set not null;

alter table public.service_offers drop column if exists price_from;
alter table public.service_offers drop column if exists price_to;

-- ------------------ 3) offer_proposals -------------------------------

create table if not exists public.offer_proposals (
    id              uuid        primary key default gen_random_uuid(),
    offer_id        uuid        not null references public.service_offers(id) on delete cascade,
    client_id       uuid        not null references public.profiles(id) on delete cascade,
    organizer_id    uuid        not null references public.profiles(id) on delete cascade,
    current_price   numeric     not null,
    last_proposer   text        not null check (last_proposer in ('client', 'organizer')),
    last_message    text,
    status          text        not null default 'pending'
                    check (status in ('pending', 'accepted', 'rejected', 'withdrawn')),
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    -- Una sola negoziazione attiva per coppia (offer, client).
    -- Se la precedente è chiusa (accepted/rejected/withdrawn) se ne può creare una nuova,
    -- ma a livello query lavoriamo sempre sulla più recente.
    unique (offer_id, client_id, created_at)
);

create index if not exists offer_proposals_offer_idx
    on public.offer_proposals(offer_id);
create index if not exists offer_proposals_client_idx
    on public.offer_proposals(client_id);
create index if not exists offer_proposals_organizer_idx
    on public.offer_proposals(organizer_id);
create index if not exists offer_proposals_status_idx
    on public.offer_proposals(status);

drop trigger if exists offer_proposals_set_updated_at on public.offer_proposals;
create trigger offer_proposals_set_updated_at
    before update on public.offer_proposals
    for each row
    execute function public.set_updated_at();

-- ------------------ 4) offer_proposal_rounds -------------------------

create table if not exists public.offer_proposal_rounds (
    id              uuid        primary key default gen_random_uuid(),
    proposal_id     uuid        not null references public.offer_proposals(id) on delete cascade,
    proposer_role   text        not null check (proposer_role in ('client', 'organizer')),
    price           numeric     not null,
    message         text,
    created_at      timestamptz not null default now()
);

create index if not exists offer_proposal_rounds_proposal_idx
    on public.offer_proposal_rounds(proposal_id, created_at desc);

-- ------------------ 5) offer_dismissals ------------------------------

create table if not exists public.offer_dismissals (
    client_id   uuid        not null references public.profiles(id) on delete cascade,
    offer_id    uuid        not null references public.service_offers(id) on delete cascade,
    created_at  timestamptz not null default now(),
    primary key (client_id, offer_id)
);

-- =====================================================================
-- RLS
-- =====================================================================

alter table public.offer_proposals          enable row level security;
alter table public.offer_proposal_rounds    enable row level security;
alter table public.offer_dismissals         enable row level security;

-- ---- offer_proposals: vedono solo cliente o organizzatore coinvolti

drop policy if exists "op_select_involved" on public.offer_proposals;
create policy "op_select_involved" on public.offer_proposals
    for select to authenticated
    using (auth.uid() = client_id or auth.uid() = organizer_id);

-- Solo il cliente può creare una nuova trattativa, ed è coerente con
-- l'offerta che sta proponendo.
drop policy if exists "op_insert_client" on public.offer_proposals;
create policy "op_insert_client" on public.offer_proposals
    for insert to authenticated
    with check (
        auth.uid() = client_id
        and exists (
            select 1 from public.service_offers o
            where o.id = offer_id
              and o.organizer_id = offer_proposals.organizer_id
        )
    );

-- Sia cliente che organizzatore possono fare update (per accettare, rifiutare,
-- contropropore, ritirare). I controlli logici sui valori validi sono fatti
-- a livello applicativo + check constraint.
drop policy if exists "op_update_involved" on public.offer_proposals;
create policy "op_update_involved" on public.offer_proposals
    for update to authenticated
    using (auth.uid() = client_id or auth.uid() = organizer_id)
    with check (auth.uid() = client_id or auth.uid() = organizer_id);

-- ---- offer_proposal_rounds: ereditano i permessi della trattativa

drop policy if exists "opr_select_involved" on public.offer_proposal_rounds;
create policy "opr_select_involved" on public.offer_proposal_rounds
    for select to authenticated
    using (
        exists (
            select 1 from public.offer_proposals p
            where p.id = proposal_id
              and (auth.uid() = p.client_id or auth.uid() = p.organizer_id)
        )
    );

-- Inserimento round: solo da chi è effettivamente parte della trattativa,
-- e il ruolo dichiarato deve combaciare con l'utente.
drop policy if exists "opr_insert_involved" on public.offer_proposal_rounds;
create policy "opr_insert_involved" on public.offer_proposal_rounds
    for insert to authenticated
    with check (
        exists (
            select 1 from public.offer_proposals p
            where p.id = proposal_id
              and (
                (proposer_role = 'client'    and auth.uid() = p.client_id)
                or (proposer_role = 'organizer' and auth.uid() = p.organizer_id)
              )
        )
    );

-- ---- offer_dismissals: solo il cliente proprietario

drop policy if exists "od_select_owner" on public.offer_dismissals;
create policy "od_select_owner" on public.offer_dismissals
    for select to authenticated
    using (auth.uid() = client_id);

drop policy if exists "od_insert_owner" on public.offer_dismissals;
create policy "od_insert_owner" on public.offer_dismissals
    for insert to authenticated
    with check (auth.uid() = client_id);

drop policy if exists "od_delete_owner" on public.offer_dismissals;
create policy "od_delete_owner" on public.offer_dismissals
    for delete to authenticated
    using (auth.uid() = client_id);

-- =====================================================================
-- 6) Auto-archive: chiude le richieste con event_date passata.
--    Funzione invocabile manualmente o via pg_cron.
-- =====================================================================

create or replace function public.auto_close_expired_requests()
returns integer
language plpgsql
security definer
as $$
declare
    closed_count integer;
begin
    update public.requests
    set status = 'closed'
    where status = 'open'
      and event_date_tbd = false
      and event_date is not null
      and event_date < current_date;

    get diagnostics closed_count = row_count;
    return closed_count;
end;
$$;

-- Se pg_cron è disponibile, schedula la chiusura una volta al giorno alle 03:00 UTC.
-- (Se l'estensione non c'è, lo SKIP non rompe la migrazione.)
do $$
begin
    if exists (select 1 from pg_extension where extname = 'pg_cron') then
        perform cron.unschedule('brindoo_auto_close_requests')
            from cron.job
            where jobname = 'brindoo_auto_close_requests';

        perform cron.schedule(
            'brindoo_auto_close_requests',
            '0 3 * * *',
            $cron$select public.auto_close_expired_requests();$cron$
        );
    end if;
end$$;
