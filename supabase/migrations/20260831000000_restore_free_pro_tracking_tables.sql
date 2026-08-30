-- =====================================================================
-- Ripristino delle tabelle di 20260515100000_free_vs_pro_matrix.sql
--
-- Quella migrazione risulta applicata nello storico remoto, ma le sue
-- tabelle sul database di produzione non ci sono (verificato il
-- 2026-08-31 con PostgREST: PGRST205 su offer_favorites, profile_views
-- e offer_views, mentre organizer_favorites risponde 200). Effetti
-- visibili dall'app: i preferiti sulle offerte falliscono sempre e le
-- visite a profilo/offerta non vengono mai contate, quindi le
-- statistiche Pro restano a zero.
--
-- Siccome lo storico le dà per fatte, `db push` non le rieseguirebbe:
-- serve questa migrazione. Tutto è idempotente, quindi è innocua anche
-- dove gli oggetti esistessero già.
--
-- Rispetto all'originale c'è in più la revoca esplicita ad `anon`: il
-- progetto concede in automatico `select` ad anon sui nuovi oggetti di
-- `public`, e le RLS da sole lascerebbero passare un 200 con lista
-- vuota invece di un rifiuto.
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

revoke all on public.offer_favorites from anon;

-- 2) Visite ai profili ------------------------------------------------

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

revoke all on public.profile_views from anon;

-- 3) Visite alle offerte ----------------------------------------------

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

revoke all on public.offer_views from anon;

-- 4) Indice per l'ordinamento con Boost -------------------------------

create index if not exists profiles_boost_active_idx
    on public.profiles(boost_expires_at desc nulls last);

-- Conferma nell'output di `db push`.
do $$
declare n int;
begin
    select count(*) into n
    from information_schema.tables
    where table_schema = 'public'
      and table_name in ('offer_favorites', 'profile_views', 'offer_views');
    raise notice 'Brindoo: tabelle di tracciamento presenti = % su 3', n;
end$$;
