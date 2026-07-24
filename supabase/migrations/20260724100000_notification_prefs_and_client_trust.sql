-- Preferenze notifiche per categoria + affidabilità del cliente.
--
-- 1. L'utente può scegliere quali notifiche ricevere (messaggi, trattative,
--    promemoria) invece dell'interruttore unico tutto-o-niente.
--    Il filtro è sul server: una notifica di categoria spenta non entra
--    nemmeno nella coda di invio.
--
-- 2. Fiducia a due sensi: il professionista può dire com'è andata con il
--    cliente dopo un evento. Il conteggio diventa un distintivo pubblico
--    ("cliente affidabile"), senza testo libero visibile ad altri.

-- MARK: - 1. Preferenze notifiche

alter table public.profiles
  add column if not exists notify_messages boolean not null default true,
  add column if not exists notify_negotiations boolean not null default true,
  add column if not exists notify_reminders boolean not null default true;

alter table public.notifications_outbox
  add column if not exists category text not null default 'other';

create or replace function public.skip_muted_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  allowed boolean;
begin
  -- Le righe inserite da vecchi trigger non indicano la categoria:
  -- la ricaviamo dal tipo di evento nel payload.
  if new.category is null or new.category = 'other' then
    new.category := case new.payload ->> 'type'
      when 'new_message'       then 'message'
      when 'new_proposal'      then 'negotiation'
      when 'proposal_counter'  then 'negotiation'
      when 'proposal_accepted' then 'negotiation'
      when 'event_reminder'    then 'reminder'
      else 'other'
    end;
  end if;

  select case new.category
           when 'message'     then p.notify_messages
           when 'negotiation' then p.notify_negotiations
           when 'reminder'    then p.notify_reminders
           else true
         end
    into allowed
  from public.profiles p
  where p.id = new.recipient_id;

  -- Categoria spenta dal destinatario: la riga viene scartata in silenzio.
  if allowed is false then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_skip_muted_notifications on public.notifications_outbox;
create trigger trg_skip_muted_notifications
  before insert on public.notifications_outbox
  for each row execute function public.skip_muted_notifications();

-- MARK: - 2. Com'è andata col cliente

create table if not exists public.client_feedback (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.offer_proposals(id) on delete cascade,
  organizer_id uuid not null references public.profiles(id) on delete cascade,
  client_id uuid not null references public.profiles(id) on delete cascade,
  -- honored = tutto regolare; no_show = non si è presentato;
  -- cancelled_late = ha annullato all'ultimo.
  outcome text not null check (outcome in ('honored', 'no_show', 'cancelled_late')),
  created_at timestamptz not null default now(),
  unique (proposal_id)
);

create index if not exists client_feedback_client_idx
  on public.client_feedback (client_id);

alter table public.client_feedback enable row level security;

-- Legge solo chi è coinvolto: il professionista che ha scritto e il cliente
-- riguardato (che ha diritto di sapere cosa lo riguarda).
drop policy if exists client_feedback_select on public.client_feedback;
create policy client_feedback_select on public.client_feedback
  for select using (
    auth.uid() = organizer_id or auth.uid() = client_id
  );

-- Scrive solo il professionista della trattativa, e solo a evento concluso.
drop policy if exists client_feedback_insert on public.client_feedback;
create policy client_feedback_insert on public.client_feedback
  for insert with check (
    auth.uid() = organizer_id
    and exists (
      select 1 from public.offer_proposals p
      where p.id = proposal_id
        and p.organizer_id = auth.uid()
        and p.client_id = client_feedback.client_id
        and p.status = 'accepted'
    )
  );

-- Conteggi pubblici aggregati: nessun dettaglio su chi ha detto cosa.
create or replace view public.client_trust_stats
with (security_invoker = off) as
  select
    client_id,
    count(*) filter (where outcome = 'honored')        as honored_count,
    count(*) filter (where outcome = 'no_show')        as no_show_count,
    count(*) filter (where outcome = 'cancelled_late') as cancelled_late_count,
    count(*)                                           as total_count
  from public.client_feedback
  group by client_id;

grant select on public.client_trust_stats to anon, authenticated;
