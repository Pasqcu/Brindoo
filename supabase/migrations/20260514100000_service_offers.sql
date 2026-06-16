-- =====================================================================
-- Service Offers: offerte pubblicate dagli organizzatori in Esplora.
-- Mirror funzionale di "requests" ma lato organizzatore.
-- =====================================================================

-- 1) Tabella principale
create table if not exists public.service_offers (
    id              uuid        primary key default gen_random_uuid(),
    organizer_id    uuid        not null references public.profiles(id) on delete cascade,
    title           text        not null,
    description     text        not null,
    coverage_area   text        not null,
    price_from      numeric,
    price_to        numeric,
    status          text        not null default 'active',
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    constraint service_offers_status_check check (status in ('active', 'paused'))
);

create index if not exists service_offers_organizer_idx
    on public.service_offers(organizer_id);

create index if not exists service_offers_status_created_idx
    on public.service_offers(status, created_at desc);

-- 2) Trigger updated_at (riusa la funzione moddatetime se presente,
--    altrimenti definisce una funzione locale equivalente).
do $$
begin
    if not exists (
        select 1 from pg_proc
        where proname = 'moddatetime'
    ) then
        create or replace function public.set_updated_at()
        returns trigger language plpgsql as $fn$
        begin
            new.updated_at = now();
            return new;
        end;
        $fn$;
    end if;
end$$;

drop trigger if exists service_offers_set_updated_at on public.service_offers;

create trigger service_offers_set_updated_at
    before update on public.service_offers
    for each row
    execute function public.set_updated_at();

-- 3) Join table categorie ↔ offerta
create table if not exists public.service_offer_categories (
    offer_id    uuid not null references public.service_offers(id) on delete cascade,
    category_id uuid not null references public.service_categories(id) on delete cascade,
    primary key (offer_id, category_id)
);

create index if not exists service_offer_categories_category_idx
    on public.service_offer_categories(category_id);

-- =====================================================================
-- RLS
-- =====================================================================

alter table public.service_offers enable row level security;
alter table public.service_offer_categories enable row level security;

-- Tutti gli utenti autenticati possono leggere le offerte.
drop policy if exists "service_offers_select_all" on public.service_offers;
create policy "service_offers_select_all" on public.service_offers
    for select
    to authenticated
    using (true);

-- Solo l'organizzatore proprietario inserisce, e solo i profili
-- con ruolo organizer possono creare offerte.
drop policy if exists "service_offers_insert_owner" on public.service_offers;
create policy "service_offers_insert_owner" on public.service_offers
    for insert
    to authenticated
    with check (
        organizer_id = auth.uid()
        and exists (
            select 1 from public.profiles p
            where p.id = auth.uid() and p.role = 'organizer'
        )
    );

drop policy if exists "service_offers_update_owner" on public.service_offers;
create policy "service_offers_update_owner" on public.service_offers
    for update
    to authenticated
    using (organizer_id = auth.uid())
    with check (organizer_id = auth.uid());

drop policy if exists "service_offers_delete_owner" on public.service_offers;
create policy "service_offers_delete_owner" on public.service_offers
    for delete
    to authenticated
    using (organizer_id = auth.uid());

-- Join table: lettura libera, scrittura/cancellazione solo dal proprietario dell'offerta.
drop policy if exists "soc_select_all" on public.service_offer_categories;
create policy "soc_select_all" on public.service_offer_categories
    for select
    to authenticated
    using (true);

drop policy if exists "soc_insert_owner" on public.service_offer_categories;
create policy "soc_insert_owner" on public.service_offer_categories
    for insert
    to authenticated
    with check (
        exists (
            select 1 from public.service_offers o
            where o.id = offer_id and o.organizer_id = auth.uid()
        )
    );

drop policy if exists "soc_delete_owner" on public.service_offer_categories;
create policy "soc_delete_owner" on public.service_offer_categories
    for delete
    to authenticated
    using (
        exists (
            select 1 from public.service_offers o
            where o.id = offer_id and o.organizer_id = auth.uid()
        )
    );
