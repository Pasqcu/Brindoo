-- =====================================================================
-- Regole delle interazioni fra utenti, garantite dal database.
--
-- 1) Blocchi. La policy di `blocked_users` mostrava a ciascuno solo i
--    blocchi fatti da lui: chi veniva bloccato non lo sapeva, quindi
--    l'app non poteva nascondergli nulla, e il server non controllava
--    niente. Chi era bloccato continuava a scrivere, proporre, recensire.
-- 2) Recensioni. Il professionista non poteva rispondere (UPDATE solo al
--    cliente), il cliente poteva scrivere nella "risposta" e decidere da
--    solo se la propria recensione era "verificata".
-- 3) Trattative. Entrambe le parti potevano scrivere qualunque colonna:
--    accettare la propria proposta, cambiare il prezzo di un accordo
--    chiuso, segnare "svolto" un evento non ancora avvenuto, prenotare
--    due eventi nello stesso giorno.
-- 4) Notifiche delle trattative. L'app le inseriva in `notifications_outbox`,
--    che ha RLS attiva e nessuna policy: venivano rifiutate tutte. Ora le
--    genera il database, come gia' faceva per messaggi e recensioni.
-- =====================================================================


-- 1) Blocchi -----------------------------------------------------------------

drop policy if exists "Utente vede chi lo ha bloccato" on public.blocked_users;
create policy "Utente vede chi lo ha bloccato" on public.blocked_users
    for select to authenticated
    using (auth.uid() = blocked_id);

create or replace function public.brindoo_is_blocked_between(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.blocked_users
         where (blocker_id = a and blocked_id = b)
            or (blocker_id = b and blocked_id = a)
    );
$$;

revoke all on function public.brindoo_is_blocked_between(uuid, uuid) from public, anon, authenticated;

-- Testo riconosciuto dall'app (BrindooErrorText): se cambia, cambia anche li'.
create or replace function public.brindoo_guard_blocked_pair()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    a uuid;
    b uuid;
begin
    if tg_table_name = 'messages' then
        select new.sender_id,
               case when c.client_id = new.sender_id then c.organizer_id else c.client_id end
          into a, b
          from public.conversations c
         where c.id = new.conversation_id;
    elsif tg_table_name = 'conversations' then
        a := new.client_id;  b := new.organizer_id;
    elsif tg_table_name = 'reviews' then
        a := new.client_id;  b := new.organizer_id;
    end if;

    if a is not null and b is not null and public.brindoo_is_blocked_between(a, b) then
        raise exception 'Utente bloccato: non potete interagire'
            using errcode = '42501';
    end if;
    return new;
end;
$$;

revoke all on function public.brindoo_guard_blocked_pair() from public, anon, authenticated;

drop trigger if exists messages_guard_blocked on public.messages;
create trigger messages_guard_blocked
    before insert on public.messages
    for each row execute function public.brindoo_guard_blocked_pair();

drop trigger if exists conversations_guard_blocked on public.conversations;
create trigger conversations_guard_blocked
    before insert on public.conversations
    for each row execute function public.brindoo_guard_blocked_pair();

drop trigger if exists reviews_guard_blocked on public.reviews;
create trigger reviews_guard_blocked
    before insert on public.reviews
    for each row execute function public.brindoo_guard_blocked_pair();


-- 2) Recensioni ----------------------------------------------------------------

-- Si recensisce solo dopo un evento svolto: segnato "svolto", oppure con la
-- data passata e non annullato. E' la stessa regola dell'app
-- (OfferProposal.allowsReview) e del contrassegno "Verificata".
create or replace function public.brindoo_can_review(p_organizer uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select auth.uid() is not null
       and auth.uid() <> p_organizer
       and exists (
            select 1 from public.offer_proposals p
             where p.client_id = auth.uid()
               and p.organizer_id = p_organizer
               and p.status = 'accepted'
               and (p.booking_status = 'completed'
                    or (p.event_date < public.brindoo_rome_today()
                        and coalesce(p.booking_status, 'confirmed') <> 'cancelled'))
       );
$$;

revoke all on function public.brindoo_can_review(uuid) from public, anon;
grant execute on function public.brindoo_can_review(uuid) to authenticated;

-- Il ruolo non conta piu': conta avere avuto l'evento. Chi era cliente e poi
-- e' diventato professionista puo' recensire chi ha ingaggiato allora.
drop policy if exists "Cliente crea recensione" on public.reviews;
create policy "Cliente crea recensione" on public.reviews
    for insert to authenticated
    with check (auth.uid() = client_id and public.brindoo_can_review(organizer_id));

create or replace function public.brindoo_reviews_protect_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if tg_op = 'INSERT' then
        -- La policy garantisce l'evento svolto: e' verificata per costruzione.
        new.verified := true;
        new.reply    := null;
        new.reply_at := null;
        return new;
    end if;

    new.client_id    := old.client_id;
    new.organizer_id := old.organizer_id;
    new.verified     := old.verified;

    if coalesce(current_setting('brindoo.review_reply', true), '') = 'on' then
        -- Risposta del professionista: tocca solo la risposta.
        new.rating    := old.rating;
        new.comment   := old.comment;
        new.photo_url := old.photo_url;
    else
        -- Modifica del cliente: la risposta non e' sua.
        new.reply    := old.reply;
        new.reply_at := old.reply_at;
    end if;
    return new;
end;
$$;

revoke all on function public.brindoo_reviews_protect_fields() from public, anon, authenticated;

drop trigger if exists reviews_protect_fields on public.reviews;
create trigger reviews_protect_fields
    before insert or update on public.reviews
    for each row execute function public.brindoo_reviews_protect_fields();

create or replace function public.brindoo_reply_to_review(p_review_id uuid, p_reply text)
returns public.reviews
language plpgsql
security definer
set search_path = public
as $$
declare
    v_review public.reviews;
    v_text   text := nullif(trim(coalesce(p_reply, '')), '');
begin
    select * into v_review from public.reviews where id = p_review_id;
    if v_review.id is null or v_review.organizer_id is distinct from auth.uid() then
        raise exception 'Puoi rispondere solo alle recensioni che hai ricevuto'
            using errcode = '42501';
    end if;
    if length(v_text) > 1000 then
        raise exception 'La risposta supera i 1000 caratteri' using errcode = '22001';
    end if;

    perform set_config('brindoo.review_reply', 'on', true);
    update public.reviews
       set reply    = v_text,
           reply_at = case when v_text is null then null else now() end
     where id = p_review_id
    returning * into v_review;
    perform set_config('brindoo.review_reply', 'off', true);

    return v_review;
end;
$$;

revoke all on function public.brindoo_reply_to_review(uuid, text) from public, anon;
grant execute on function public.brindoo_reply_to_review(uuid, text) to authenticated;


-- 3) Trattative: chi puo' fare cosa -------------------------------------------

create or replace function public.brindoo_date_already_booked(
    p_organizer uuid, p_day date, p_except uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select p_day is not null and exists (
        select 1 from public.offer_proposals x
         where x.organizer_id = p_organizer
           and x.id <> p_except
           and x.status = 'accepted'
           and coalesce(x.booking_status, 'confirmed') <> 'cancelled'
           and x.event_date = p_day
    );
$$;

revoke all on function public.brindoo_date_already_booked(uuid, date, uuid) from public, anon, authenticated;

create or replace function public.brindoo_guard_offer_proposal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    actor      uuid := auth.uid();
    actor_role text;
    v_today    date := public.brindoo_rome_today();
    negotiated boolean;
begin
    -- Server, lavori pianificati e migrazioni non passano da qui.
    if actor is null then
        return new;
    end if;

    if tg_op = 'INSERT' then
        if new.client_id <> actor or new.status <> 'pending' or new.last_proposer <> 'client' then
            raise exception 'Proposta non valida' using errcode = '42501';
        end if;
        if public.brindoo_is_blocked_between(new.client_id, new.organizer_id) then
            raise exception 'Utente bloccato: non potete interagire' using errcode = '42501';
        end if;
        if exists (select 1 from public.profiles
                    where id = new.organizer_id and vacation_until > v_today) then
            raise exception 'Il professionista e'' in vacanza: riprova quando torna disponibile'
                using errcode = '42501';
        end if;
        new.booking_status := null;
        return new;
    end if;

    if new.offer_id <> old.offer_id or new.client_id <> old.client_id
       or new.organizer_id <> old.organizer_id then
        raise exception 'Trattativa non modificabile' using errcode = '42501';
    end if;

    actor_role := case when actor = old.client_id then 'client'
                       when actor = old.organizer_id then 'organizer' end;
    if actor_role is null then
        raise exception 'Trattativa non tua' using errcode = '42501';
    end if;

    negotiated := new.current_price is distinct from old.current_price
               or new.last_proposer is distinct from old.last_proposer
               or new.last_message  is distinct from old.last_message;

    if old.status = 'pending' then
        if new.status = 'pending' and negotiated then
            if old.last_proposer = actor_role or new.last_proposer <> actor_role then
                raise exception 'Tocca all''altra parte rispondere' using errcode = '42501';
            end if;
            if public.brindoo_is_blocked_between(old.client_id, old.organizer_id) then
                raise exception 'Utente bloccato: non potete interagire' using errcode = '42501';
            end if;
        elsif new.status = 'accepted' then
            if old.last_proposer = actor_role or negotiated then
                raise exception 'Non puoi accettare la tua stessa proposta' using errcode = '42501';
            end if;
            if public.brindoo_is_blocked_between(old.client_id, old.organizer_id) then
                raise exception 'Utente bloccato: non potete interagire' using errcode = '42501';
            end if;
            if public.brindoo_date_already_booked(new.organizer_id, new.event_date, new.id) then
                raise exception 'Data occupata: il professionista ha gia'' un evento confermato quel giorno'
                    using errcode = '23P01';
            end if;
        elsif new.status = 'rejected' then
            if old.last_proposer = actor_role or negotiated then
                raise exception 'La tua proposta si ritira, non si rifiuta' using errcode = '42501';
            end if;
        elsif new.status = 'withdrawn' then
            if old.last_proposer <> actor_role or negotiated then
                raise exception 'Puoi ritirare solo la tua proposta' using errcode = '42501';
            end if;
        end if;
    elsif new.status is distinct from old.status or negotiated then
        raise exception 'La trattativa e'' gia'' chiusa' using errcode = '42501';
    end if;

    if new.booking_status is distinct from old.booking_status then
        if new.status <> 'accepted' then
            raise exception 'Nessun accordo da aggiornare' using errcode = '42501';
        end if;
        if coalesce(old.booking_status, 'confirmed') <> 'confirmed' then
            raise exception 'L''appuntamento e'' gia'' chiuso' using errcode = '42501';
        end if;
        if new.booking_status = 'completed'
           and (new.event_date is null or new.event_date > v_today) then
            raise exception 'Si puo'' segnare svolto solo dal giorno dell''evento'
                using errcode = '42501';
        end if;
    end if;

    if new.event_date is distinct from old.event_date and old.status = 'accepted' then
        if coalesce(new.booking_status, 'confirmed') <> 'confirmed' then
            raise exception 'Appuntamento chiuso: la data non si sposta' using errcode = '42501';
        end if;
        if public.brindoo_date_already_booked(new.organizer_id, new.event_date, new.id) then
            raise exception 'Data occupata: il professionista ha gia'' un evento confermato quel giorno'
                using errcode = '23P01';
        end if;
    end if;

    return new;
end;
$$;

revoke all on function public.brindoo_guard_offer_proposal() from public, anon, authenticated;

drop trigger if exists offer_proposals_guard on public.offer_proposals;
create trigger offer_proposals_guard
    before insert or update on public.offer_proposals
    for each row execute function public.brindoo_guard_offer_proposal();


-- 4) Notifiche delle trattative ------------------------------------------------

create or replace function public.brindoo_notify_offer_proposal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_title     text;
    v_actor     uuid := auth.uid();
    v_actor_nm  text;
    v_recipient uuid;
    v_head      text;
    v_body      text;
    v_type      text;
begin
    select title into v_title from public.service_offers where id = new.offer_id;
    v_title := coalesce(v_title, 'Offerta');

    if tg_op = 'INSERT' then
        v_actor     := new.client_id;
        v_recipient := new.organizer_id;
        v_type      := 'new_proposal';
    elsif old.status = 'pending' and new.status = 'pending'
          and (new.current_price is distinct from old.current_price
               or new.last_proposer is distinct from old.last_proposer) then
        v_actor     := case when new.last_proposer = 'client' then new.client_id else new.organizer_id end;
        v_type      := 'proposal_counter';
    elsif old.status = 'pending' and new.status = 'accepted' then
        v_type      := 'proposal_accepted';
    elsif old.status = 'pending' and new.status = 'rejected' then
        v_type      := 'proposal_rejected';
    elsif old.status = 'pending' and new.status = 'withdrawn' then
        v_type      := 'proposal_withdrawn';
    elsif coalesce(old.booking_status, 'confirmed') = 'confirmed'
          and new.booking_status = 'cancelled' then
        v_type      := 'booking_cancelled';
    else
        return new;
    end if;

    -- Chi agisce: dove il database non lo sa (server), si deduce dal turno.
    if v_actor is null then
        v_actor := case when old.last_proposer = 'client' then new.organizer_id else new.client_id end;
        if v_type = 'proposal_withdrawn' then
            v_actor := case when old.last_proposer = 'client' then new.client_id else new.organizer_id end;
        end if;
    end if;
    if v_recipient is null then
        v_recipient := case when v_actor = new.client_id then new.organizer_id else new.client_id end;
    end if;

    select coalesce(nullif(trim(full_name), ''), 'Un utente') into v_actor_nm
      from public.profiles where id = v_actor;
    v_actor_nm := coalesce(v_actor_nm, 'Un utente');

    case v_type
        when 'new_proposal' then
            v_head := 'Nuova proposta su ' || v_title;
            v_body := v_actor_nm || ' ha inviato una proposta';
        when 'proposal_counter' then
            v_head := 'Controproposta da ' || v_actor_nm;
            v_body := 'Nuova controproposta su "' || v_title || '"';
        when 'proposal_accepted' then
            v_head := 'Proposta accettata 🎉';
            v_body := 'La trattativa su "' || v_title || '" è andata in porto';
        when 'proposal_rejected' then
            v_head := 'Proposta rifiutata';
            v_body := v_actor_nm || ' ha rifiutato la proposta su "' || v_title || '"';
        when 'proposal_withdrawn' then
            v_head := 'Proposta ritirata';
            v_body := v_actor_nm || ' ha ritirato la proposta su "' || v_title || '"';
        else
            v_head := 'Evento annullato';
            v_body := v_actor_nm || ' ha annullato "' || v_title || '"'
                      || case when new.event_date is null then ''
                              else ' del ' || to_char(new.event_date, 'DD/MM/YYYY') end;
    end case;

    insert into public.notifications_outbox (recipient_id, title, body, category, payload)
    values (v_recipient, v_head, v_body, 'negotiation',
            jsonb_build_object('type', v_type, 'offer_id', new.offer_id::text));
    return new;
end;
$$;

revoke all on function public.brindoo_notify_offer_proposal() from public, anon, authenticated;

drop trigger if exists offer_proposals_notify on public.offer_proposals;
create trigger offer_proposals_notify
    after insert or update on public.offer_proposals
    for each row execute function public.brindoo_notify_offer_proposal();


-- 5) Anteprima dei vocali ------------------------------------------------------
--
-- I vocali viaggiano come message_type 'image' con un .m4a: la notifica
-- diceva "📷 Foto". Il testo del messaggio contiene gia' la dicitura giusta.

create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_recipient_id uuid;
    v_sender_name  text;
    v_body_preview text;
begin
    select case when c.client_id = new.sender_id then c.organizer_id else c.client_id end
      into v_recipient_id
      from public.conversations c
     where c.id = new.conversation_id;

    select coalesce(full_name, 'Utente') into v_sender_name
      from public.profiles where id = new.sender_id;

    v_body_preview := case
        when new.message_type = 'image' and coalesce(new.image_url, '') ilike '%.m4a'
            then left(coalesce(new.content, '🎤 Messaggio vocale'), 80)
        when new.message_type = 'image' then '📷 Foto'
        when new.message_type = 'bomb_image' then '💣 Foto bomba'
        else left(coalesce(new.content, ''), 80)
    end;

    insert into public.notifications_outbox (recipient_id, title, body, payload)
    values (
        v_recipient_id,
        v_sender_name,
        v_body_preview,
        jsonb_build_object(
            'type', 'new_message',
            'conversation_id', new.conversation_id::text,
            'sender_id', new.sender_id::text
        )
    );
    return new;
end;
$$;
