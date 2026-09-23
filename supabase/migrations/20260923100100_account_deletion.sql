-- =====================================================================
-- Eliminazione dell'account.
--
-- `delete_my_account()` cancellava da `public.applications` e
-- `public.requests`, tabelle dello schema vecchio che in produzione non
-- esistono piu': la funzione andava in errore alla seconda riga e nessun
-- account si poteva eliminare.
--
-- Adesso si cancella solo `auth.users`: tutte le tabelle dell'app puntano
-- li' (o a `profiles`, che punta li') con `on delete cascade`.
--
-- Chi resta dall'altra parte di un accordo ancora da svolgere:
--   * riceve una notifica ("evento annullato");
--   * se e' il professionista, ritrova quel giorno segnalato nel proprio
--     calendario (`booking_cancellation_notices`) e decide se liberarlo o
--     tenerlo occupato.
--
-- Il blocco sulla cancellazione delle offerte con accordi (20260727100000)
-- non vale per chi chiude l'account: la cascata altrimenti si fermerebbe
-- proprio sui professionisti con piu' lavoro alle spalle.
-- =====================================================================

-- 0) Giorno civile di riferimento (gli eventi sono nel Lazio) ------------

create or replace function public.brindoo_rome_today()
returns date
language sql
stable
as $$
    select (now() at time zone 'Europe/Rome')::date;
$$;

comment on function public.brindoo_rome_today() is
    'Oggi a Roma: gli eventi hanno giorni civili, non istanti.';

revoke all on function public.brindoo_rome_today() from public, anon;
grant execute on function public.brindoo_rome_today() to authenticated, service_role;


-- 1) Avvisi per i giorni liberati --------------------------------------------

create table if not exists public.booking_cancellation_notices (
    id               uuid primary key default gen_random_uuid(),
    recipient_id     uuid not null references public.profiles(id) on delete cascade,
    event_date       date not null,
    offer_title      text,
    counterpart_name text,
    reason           text not null default 'account_deleted',
    created_at       timestamptz not null default now()
);

create index if not exists booking_cancellation_notices_recipient_idx
    on public.booking_cancellation_notices(recipient_id, event_date);

alter table public.booking_cancellation_notices enable row level security;

drop policy if exists bcn_select_own on public.booking_cancellation_notices;
create policy bcn_select_own on public.booking_cancellation_notices
    for select to authenticated
    using (auth.uid() = recipient_id);

drop policy if exists bcn_delete_own on public.booking_cancellation_notices;
create policy bcn_delete_own on public.booking_cancellation_notices
    for delete to authenticated
    using (auth.uid() = recipient_id);

revoke all on public.booking_cancellation_notices from anon;
grant select, delete on public.booking_cancellation_notices to authenticated;


-- 2) Il blocco delle offerte non ferma la chiusura dell'account ---------------

create or replace function public.service_offers_block_delete_with_agreements()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_count int;
begin
    if coalesce(current_setting('brindoo.account_deletion', true), '') = 'on' then
        return old;
    end if;

    select count(*)
      into v_count
      from public.offer_proposals p
     where p.offer_id = old.id
       and p.status = 'accepted'
       and coalesce(p.booking_status, 'confirmed') <> 'cancelled';

    if v_count > 0 then
        raise exception
            'Questa offerta ha % accordi confermati e non puo'' essere eliminata.', v_count
            using errcode = '23503';
    end if;
    return old;
end;
$$;


-- 3) Cancellazione vera e propria ---------------------------------------------

create or replace function public.brindoo_delete_account(target uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_name  text;
    v_other uuid;
    v_when  text;
    r       record;
begin
    if target is null then
        raise exception 'Utente non valido' using errcode = '22023';
    end if;

    select coalesce(nullif(trim(full_name), ''), 'Un utente') into v_name
      from public.profiles where id = target;
    v_name := coalesce(v_name, 'Un utente');

    -- Accordi ancora da svolgere: l'altra parte va avvisata.
    for r in
        select p.client_id, p.organizer_id, p.event_date, o.title
          from public.offer_proposals p
          join public.service_offers o on o.id = p.offer_id
         where (p.client_id = target or p.organizer_id = target)
           and p.status = 'accepted'
           and coalesce(p.booking_status, 'confirmed') = 'confirmed'
           and (p.event_date is null or p.event_date >= public.brindoo_rome_today())
    loop
        v_other := case when r.client_id = target then r.organizer_id else r.client_id end;
        v_when  := case when r.event_date is null then ''
                        else ' del ' || to_char(r.event_date, 'DD/MM/YYYY') end;

        insert into public.notifications_outbox (recipient_id, title, body, category, payload)
        values (
            v_other,
            'Evento annullato',
            v_name || ' ha eliminato l''account: l''accordo per "' || r.title || '"'
                || v_when || ' non e'' piu'' valido.',
            'negotiation',
            jsonb_build_object('type', 'agreement_removed')
        );

        -- Il professionista ritrova il giorno segnalato nel calendario.
        if r.event_date is not null and v_other = r.organizer_id then
            insert into public.booking_cancellation_notices
                (recipient_id, event_date, offer_title, counterpart_name)
            values (v_other, r.event_date, r.title, v_name);
        end if;
    end loop;

    perform set_config('brindoo.account_deletion', 'on', true);
    delete from auth.users where id = target;
    perform set_config('brindoo.account_deletion', 'off', true);
end;
$$;

comment on function public.brindoo_delete_account(uuid) is
    'Elimina un account e tutti i suoi dati (cascata da auth.users), dopo aver '
    'avvisato le controparti degli accordi ancora da svolgere. Solo service_role: '
    'la chiama la edge function delete-account, che pulisce anche lo storage.';

revoke all on function public.brindoo_delete_account(uuid) from public, anon, authenticated;
grant execute on function public.brindoo_delete_account(uuid) to service_role;

-- Versioni dell'app gia' installate chiamano ancora questa RPC.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'Utente non autenticato' using errcode = '42501';
    end if;
    perform public.brindoo_delete_account(auth.uid());
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
