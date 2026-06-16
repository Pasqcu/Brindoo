-- =====================================================================
-- 1) Risposta dell'organizzatore alle recensioni
-- 2) Date di non-disponibilità degli organizzatori (calendario)
-- =====================================================================

-- 1) Risposta alle recensioni ----------------------------------------
alter table public.reviews
    add column if not exists reply text;
alter table public.reviews
    add column if not exists reply_at timestamptz;

-- 2) Disponibilità organizzatore -------------------------------------
create table if not exists public.organizer_unavailable_dates (
    organizer_id uuid        not null references public.profiles(id) on delete cascade,
    day          date        not null,
    created_at   timestamptz not null default now(),
    primary key (organizer_id, day)
);

create index if not exists organizer_unavailable_org_idx
    on public.organizer_unavailable_dates(organizer_id, day);

alter table public.organizer_unavailable_dates enable row level security;

-- Lettura: tutti gli autenticati (i clienti devono poter evitare quei giorni).
drop policy if exists "oud_select_auth" on public.organizer_unavailable_dates;
create policy "oud_select_auth" on public.organizer_unavailable_dates
    for select to authenticated
    using (auth.uid() is not null);

-- Scrittura: solo il proprietario del calendario.
drop policy if exists "oud_insert_owner" on public.organizer_unavailable_dates;
create policy "oud_insert_owner" on public.organizer_unavailable_dates
    for insert to authenticated
    with check (auth.uid() = organizer_id);

drop policy if exists "oud_delete_owner" on public.organizer_unavailable_dates;
create policy "oud_delete_owner" on public.organizer_unavailable_dates
    for delete to authenticated
    using (auth.uid() = organizer_id);
