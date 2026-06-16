-- =====================================================================
-- Free vs Pro matrix:
--   - offer_favorites    : preferiti delle offerte (lato cliente, free per tutti)
--   - profile_views      : tracking visite profilo (per statistiche Pro)
--   - offer_views        : tracking visite dettaglio offerta (per stat Pro)
--   - indici per Boost   : ordinamento profili/offerte con boost_expires_at
-- =====================================================================

-- 1) Preferiti offerte ------------------------------------------------

create table if not exists public.offer_favorites (
    client_id   uuid        not null references public.profiles(id) on delete cascade,
    offer_id    uuid        not null references public.service_offers(id) on delete cascade,
    created_at  timestamptz not null default now(),
    primary key (client_id, offer_id)
);

create index if not exists offer_favorites_client_idx
    on public.offer_favorites(client_id, created_at desc);

alter table public.offer_favorites enable row level security;

drop policy if exists "of_select_owner" on public.offer_favorites;
create policy "of_select_owner" on public.offer_favorites
    for select to authenticated
    using (auth.uid() = client_id);

drop policy if exists "of_insert_owner" on public.offer_favorites;
create policy "of_insert_owner" on public.offer_favorites
    for insert to authenticated
    with check (auth.uid() = client_id);

drop policy if exists "of_delete_owner" on public.offer_favorites;
create policy "of_delete_owner" on public.offer_favorites
    for delete to authenticated
    using (auth.uid() = client_id);

-- 2) Profile views ----------------------------------------------------

create table if not exists public.profile_views (
    id              uuid        primary key default gen_random_uuid(),
    profile_id      uuid        not null references public.profiles(id) on delete cascade,
    viewer_id       uuid        references public.profiles(id) on delete set null,
    viewed_at       timestamptz not null default now()
);

create index if not exists profile_views_profile_time_idx
    on public.profile_views(profile_id, viewed_at desc);

alter table public.profile_views enable row level security;

-- Tutti gli authenticated possono inserire visite (anche su altri profili).
drop policy if exists "pv_insert_any" on public.profile_views;
create policy "pv_insert_any" on public.profile_views
    for insert to authenticated
    with check (auth.uid() is not null);

-- Solo il proprietario del profilo legge le visite (statistiche personali).
drop policy if exists "pv_select_owner" on public.profile_views;
create policy "pv_select_owner" on public.profile_views
    for select to authenticated
    using (auth.uid() = profile_id);

-- 3) Offer views ------------------------------------------------------

create table if not exists public.offer_views (
    id              uuid        primary key default gen_random_uuid(),
    offer_id        uuid        not null references public.service_offers(id) on delete cascade,
    viewer_id       uuid        references public.profiles(id) on delete set null,
    viewed_at       timestamptz not null default now()
);

create index if not exists offer_views_offer_time_idx
    on public.offer_views(offer_id, viewed_at desc);

alter table public.offer_views enable row level security;

drop policy if exists "ov_insert_any" on public.offer_views;
create policy "ov_insert_any" on public.offer_views
    for insert to authenticated
    with check (auth.uid() is not null);

-- Solo l'organizzatore proprietario dell'offerta legge.
drop policy if exists "ov_select_owner" on public.offer_views;
create policy "ov_select_owner" on public.offer_views
    for select to authenticated
    using (exists (
        select 1 from public.service_offers o
        where o.id = offer_id and o.organizer_id = auth.uid()
    ));

-- 4) Indici per Boost ordering ---------------------------------------
-- profiles.boost_expires_at è già esistente, manca solo l'indice.
-- NB: non possiamo usare WHERE boost_expires_at > now() perché now()
-- non è IMMUTABLE (richiesto da PostgreSQL per i predicati di indice
-- parziale). L'indice completo va più che bene: query come
-- `order by boost_expires_at desc nulls last` lo useranno comunque.

create index if not exists profiles_boost_active_idx
    on public.profiles(boost_expires_at desc nulls last);
