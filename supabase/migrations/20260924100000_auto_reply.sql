-- Risposta automatica del professionista ("fuori sede", stile Outlook).
--
-- Il professionista Pro la accende dalle Impostazioni, con un testo e un
-- intervallo di giorni facoltativo. Quando un cliente gli scrive, il
-- database risponde al posto suo: deve funzionare anche con l'app del
-- professionista chiusa, quindi vive qui e non nell'app.
--
-- Regole:
--   * solo messaggi del cliente verso il professionista della conversazione
--     (la risposta parte dal professionista, quindi non innesca se stessa);
--   * solo se il professionista e' Pro adesso (pro_expires_at, mai is_pro);
--   * solo dentro l'intervallo, contato sul calendario Europe/Rome, estremi
--     compresi; un estremo vuoto vuol dire "senza limite";
--   * al massimo una risposta automatica ogni 24 ore per conversazione.

-- 1) Impostazioni sul profilo ------------------------------------------------

alter table public.profiles
    add column if not exists auto_reply_enabled boolean not null default false,
    add column if not exists auto_reply_message text,
    add column if not exists auto_reply_from date,
    add column if not exists auto_reply_until date;

alter table public.profiles
    drop constraint if exists profiles_auto_reply_message_length,
    add constraint profiles_auto_reply_message_length
        check (auto_reply_message is null or char_length(auto_reply_message) <= 500);

alter table public.profiles
    drop constraint if exists profiles_auto_reply_range,
    add constraint profiles_auto_reply_range
        check (auto_reply_from is null or auto_reply_until is null or auto_reply_from <= auto_reply_until);


-- 2) Contrassegno sui messaggi -------------------------------------------------

alter table public.messages
    add column if not exists is_auto_reply boolean not null default false;

-- Il contrassegno lo mette solo il database. Un inserimento diretto dal
-- client ha profondita' 1; quello fatto dal trigger qui sotto ha profondita' 2.
create or replace function public.brindoo_guard_auto_reply_flag()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if tg_op = 'INSERT' then
        if new.is_auto_reply and pg_trigger_depth() < 2 then
            new.is_auto_reply := false;
        end if;
    else
        new.is_auto_reply := old.is_auto_reply;
    end if;
    return new;
end;
$$;

revoke all on function public.brindoo_guard_auto_reply_flag() from public, anon, authenticated;

drop trigger if exists messages_guard_auto_reply_flag on public.messages;
create trigger messages_guard_auto_reply_flag
    before insert or update on public.messages
    for each row execute function public.brindoo_guard_auto_reply_flag();


-- 3) Invio della risposta ------------------------------------------------------

create or replace function public.brindoo_send_auto_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_organizer uuid;
    v_client    uuid;
    v_text      text;
    v_today     date := (now() at time zone 'Europe/Rome')::date;
begin
    if new.is_auto_reply or new.message_type = 'system' then
        return new;
    end if;

    select c.organizer_id, c.client_id
      into v_organizer, v_client
      from public.conversations c
     where c.id = new.conversation_id;

    if v_organizer is null or new.sender_id <> v_client then
        return new;
    end if;

    select nullif(btrim(p.auto_reply_message), '')
      into v_text
      from public.profiles p
     where p.id = v_organizer
       and p.auto_reply_enabled
       and p.pro_expires_at > now()
       and (p.auto_reply_from is null or p.auto_reply_from <= v_today)
       and (p.auto_reply_until is null or p.auto_reply_until >= v_today);

    if not found then
        return new;
    end if;

    if exists (
        select 1 from public.messages m
         where m.conversation_id = new.conversation_id
           and m.is_auto_reply
           and m.created_at > now() - interval '24 hours'
    ) then
        return new;
    end if;

    -- clock_timestamp: nella stessa transazione now() e' identico al
    -- messaggio del cliente, e la chat li ordinerebbe a caso.
    insert into public.messages (conversation_id, sender_id, content, message_type, is_auto_reply, created_at)
    values (
        new.conversation_id,
        v_organizer,
        coalesce(v_text, 'Al momento non sono raggiungibile. Ti rispondero'' appena possibile.'),
        'text',
        true,
        greatest(clock_timestamp(), new.created_at + interval '1 millisecond')
    );

    return new;
end;
$$;

revoke all on function public.brindoo_send_auto_reply() from public, anon, authenticated;

drop trigger if exists on_new_message_auto_reply on public.messages;
create trigger on_new_message_auto_reply
    after insert on public.messages
    for each row execute function public.brindoo_send_auto_reply();
