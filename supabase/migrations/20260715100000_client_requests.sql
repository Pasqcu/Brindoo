-- =====================================================================
-- Richieste dei clienti (bacheca inversa):
-- il cliente pubblica cosa cerca (es. "Fotografo per matrimonio il 20/9
-- a Latina, budget 800€") e i professionisti lo contattano in chat.
-- =====================================================================

create table if not exists public.client_requests (
    id          uuid        primary key default gen_random_uuid(),
    client_id   uuid        not null references public.profiles(id) on delete cascade,
    title       text        not null,
    description text,
    area        text        not null,
    event_date  date,
    budget      numeric,
    category_id uuid        references public.service_categories(id) on delete set null,
    status      text        not null default 'open',
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    constraint client_requests_status_check check (status in ('open', 'closed'))
);

create index if not exists client_requests_status_created_idx
    on public.client_requests(status, created_at desc);

create index if not exists client_requests_client_idx
    on public.client_requests(client_id);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $fn$
begin
    new.updated_at = now();
    return new;
end;
$fn$;

drop trigger if exists client_requests_set_updated_at on public.client_requests;

create trigger client_requests_set_updated_at
    before update on public.client_requests
    for each row
    execute function public.set_updated_at();

alter table public.client_requests enable row level security;

-- Lettura: tutti gli autenticati (i professionisti sfogliano le richieste).
drop policy if exists "client_requests_select_auth" on public.client_requests;
create policy "client_requests_select_auth" on public.client_requests
    for select to authenticated
    using (auth.uid() is not null);

-- Scrittura: solo il cliente proprietario.
drop policy if exists "client_requests_insert_owner" on public.client_requests;
create policy "client_requests_insert_owner" on public.client_requests
    for insert to authenticated
    with check (auth.uid() = client_id);

drop policy if exists "client_requests_update_owner" on public.client_requests;
create policy "client_requests_update_owner" on public.client_requests
    for update to authenticated
    using (auth.uid() = client_id)
    with check (auth.uid() = client_id);

drop policy if exists "client_requests_delete_owner" on public.client_requests;
create policy "client_requests_delete_owner" on public.client_requests
    for delete to authenticated
    using (auth.uid() = client_id);
