-- =====================================================================
-- Pacchetti prezzo per le offerte (Base / Completo / Premium):
-- fino a 3 varianti per offerta, ognuna con nome, descrizione e prezzo.
-- Il prezzo "principale" dell'offerta resta la base della trattativa
-- quando il cliente non sceglie un pacchetto.
-- =====================================================================

create table if not exists public.service_offer_packages (
    id          uuid        primary key default gen_random_uuid(),
    offer_id    uuid        not null references public.service_offers(id) on delete cascade,
    name        text        not null,
    description text,
    price       numeric     not null check (price > 0),
    sort_order  int         not null default 0,
    created_at  timestamptz not null default now()
);

create index if not exists service_offer_packages_offer_idx
    on public.service_offer_packages(offer_id, sort_order);

alter table public.service_offer_packages enable row level security;

-- Lettura: tutti gli autenticati (i clienti confrontano i pacchetti).
drop policy if exists "offer_packages_select_auth" on public.service_offer_packages;
create policy "offer_packages_select_auth" on public.service_offer_packages
    for select to authenticated
    using (auth.uid() is not null);

-- Scrittura: solo il proprietario dell'offerta.
drop policy if exists "offer_packages_insert_owner" on public.service_offer_packages;
create policy "offer_packages_insert_owner" on public.service_offer_packages
    for insert to authenticated
    with check (exists (
        select 1 from public.service_offers o
        where o.id = offer_id and o.organizer_id = auth.uid()
    ));

drop policy if exists "offer_packages_update_owner" on public.service_offer_packages;
create policy "offer_packages_update_owner" on public.service_offer_packages
    for update to authenticated
    using (exists (
        select 1 from public.service_offers o
        where o.id = offer_id and o.organizer_id = auth.uid()
    ))
    with check (exists (
        select 1 from public.service_offers o
        where o.id = offer_id and o.organizer_id = auth.uid()
    ));

drop policy if exists "offer_packages_delete_owner" on public.service_offer_packages;
create policy "offer_packages_delete_owner" on public.service_offer_packages
    for delete to authenticated
    using (exists (
        select 1 from public.service_offers o
        where o.id = offer_id and o.organizer_id = auth.uid()
    ));
