-- ---------------------------------------------------------------------
-- Premio invito: un mese Pro a chi invita e a chi accetta l'invito.
--
-- Prima di questa migrazione il codice invito funzionava a meta': il
-- riscatto veniva registrato, ma `reward_granted` restava sempre false e
-- nessuno estendeva `pro_expires_at`. L'app prometteva un mese Pro che
-- non arrivava mai.
--
-- Qui il premio viene assegnato dal server quando chi ha usato il codice
-- completa il proprio profilo (nome + foto + descrizione di almeno 30
-- caratteri). Un solo premio per riscatto, garantito da `reward_granted`.
--
-- Nota sui permessi: `profiles.pro_expires_at` e' protetto dal trigger
-- `profiles_block_entitlement_update`, che accetta solo `service_role`.
-- La funzione qui sotto alza un contrassegno valido per la sola
-- transazione in corso, e il trigger di blocco viene esteso per
-- riconoscerlo. I client non possono alzarlo: passano da PostgREST, che
-- non esegue SQL arbitrario e non espone questa funzione.
-- ---------------------------------------------------------------------

-- 1) Il blocco sugli entitlement riconosce le concessioni interne -------

create or replace function public.profiles_block_client_entitlement_update()
returns trigger
language plpgsql
security definer
as $$
begin
    -- service_role / postgres bypassano questo check.
    if auth.role() = 'service_role' then
        return new;
    end if;

    -- Concessione interna in corso (premio invito): il contrassegno vive
    -- solo dentro la transazione che lo ha alzato.
    if coalesce(current_setting('brindoo.entitlement_grant', true), '') = 'on' then
        return new;
    end if;

    if new.pro_expires_at is distinct from old.pro_expires_at then
        raise exception
            'profiles.pro_expires_at can only be updated by validate-iap-receipt edge function (service_role required)'
            using errcode = '42501';
    end if;

    if new.boost_expires_at is distinct from old.boost_expires_at then
        raise exception
            'profiles.boost_expires_at can only be updated by validate-iap-receipt edge function (service_role required)'
            using errcode = '42501';
    end if;

    return new;
end;
$$;

comment on function public.profiles_block_client_entitlement_update() is
    'Impedisce ai client (anon/authenticated) di modificare le colonne di '
    'entitlement IAP. Eccezioni: service_role, e le concessioni interne '
    'che alzano brindoo.entitlement_grant per la sola transazione.';


-- 2) Quando un profilo si considera completo --------------------------

create or replace function public.brindoo_profile_is_complete(p public.profiles)
returns boolean
language sql
immutable
as $$
    select coalesce(length(trim(p.full_name)), 0) > 0
       and coalesce(length(trim(p.avatar_url)), 0) > 0
       and coalesce(length(trim(p.bio)), 0) >= 30;
$$;

comment on function public.brindoo_profile_is_complete(public.profiles) is
    'Profilo completo ai fini del premio invito: nome, foto e una '
    'descrizione di almeno 30 caratteri. Vale per clienti e professionisti.';


-- 3) Un mese Pro a un utente, sommato a quello che ha gia' -------------

create or replace function public.brindoo_grant_pro_month(target_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    -- Il mese si aggiunge alla scadenza esistente, non la sostituisce:
    -- chi ha gia' un abbonamento attivo non deve perderci.
    update public.profiles
       set pro_expires_at = greatest(coalesce(pro_expires_at, now()), now())
                            + interval '1 month'
     where id = target_id;
end;
$$;


-- 4) Assegnazione del premio al completamento del profilo -------------

create or replace function public.brindoo_referral_grant_reward()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_redemption_id uuid;
    v_code_id       uuid;
    v_inviter_id    uuid;
begin
    -- Solo nel momento in cui il profilo diventa completo.
    if public.brindoo_profile_is_complete(new) is not true then
        return new;
    end if;
    if tg_op = 'UPDATE' and public.brindoo_profile_is_complete(old) is true then
        return new;
    end if;

    -- Riscatto ancora da premiare per questo utente.
    select rr.id, rr.code_id, rc.user_id
      into v_redemption_id, v_code_id, v_inviter_id
      from public.referral_redemptions rr
      join public.referral_codes rc on rc.id = rr.code_id
     where rr.redeemer_id = new.id
       and rr.reward_granted = false
     limit 1;

    if v_redemption_id is null then
        return new;
    end if;

    -- Nessun premio a chi usa il proprio codice.
    if v_inviter_id = new.id then
        return new;
    end if;

    -- Chiude il riscatto per primo: se due aggiornamenti arrivano
    -- insieme, il secondo non trova piu' nulla da premiare.
    update public.referral_redemptions
       set reward_granted = true
     where id = v_redemption_id
       and reward_granted = false;

    if not found then
        return new;
    end if;

    update public.referral_codes
       set reward_granted_count = reward_granted_count + 1
     where id = v_code_id;

    perform set_config('brindoo.entitlement_grant', 'on', true);
    perform public.brindoo_grant_pro_month(v_inviter_id);
    perform public.brindoo_grant_pro_month(new.id);
    perform set_config('brindoo.entitlement_grant', 'off', true);

    return new;
end;
$$;

comment on function public.brindoo_referral_grant_reward() is
    'Assegna un mese Pro a chi invita e a chi e'' stato invitato, una '
    'sola volta per riscatto, quando l''invitato completa il profilo.';

drop trigger if exists brindoo_referral_grant_reward_trigger on public.profiles;
create trigger brindoo_referral_grant_reward_trigger
    after insert or update of full_name, avatar_url, bio on public.profiles
    for each row
    execute function public.brindoo_referral_grant_reward();


-- 4-bis) Codice inserito da chi ha gia' il profilo a posto -------------
--
-- L'ordine dei due gesti non e' garantito: c'e' chi completa il profilo
-- e solo dopo si ricorda del codice. In quel caso il premio scatta al
-- momento del riscatto.

create or replace function public.brindoo_referral_grant_on_redeem()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_inviter_id uuid;
    v_complete   boolean;
begin
    if new.reward_granted then
        return new;
    end if;

    select rc.user_id into v_inviter_id
      from public.referral_codes rc
     where rc.id = new.code_id;

    if v_inviter_id is null or v_inviter_id = new.redeemer_id then
        return new;
    end if;

    select public.brindoo_profile_is_complete(p) into v_complete
      from public.profiles p
     where p.id = new.redeemer_id;

    if v_complete is not true then
        return new;
    end if;

    update public.referral_redemptions
       set reward_granted = true
     where id = new.id
       and reward_granted = false;

    if not found then
        return new;
    end if;

    update public.referral_codes
       set reward_granted_count = reward_granted_count + 1
     where id = new.code_id;

    perform set_config('brindoo.entitlement_grant', 'on', true);
    perform public.brindoo_grant_pro_month(v_inviter_id);
    perform public.brindoo_grant_pro_month(new.redeemer_id);
    perform set_config('brindoo.entitlement_grant', 'off', true);

    return new;
end;
$$;

drop trigger if exists brindoo_referral_grant_on_redeem_trigger on public.referral_redemptions;
create trigger brindoo_referral_grant_on_redeem_trigger
    after insert on public.referral_redemptions
    for each row
    execute function public.brindoo_referral_grant_on_redeem();


-- 5) Recupero degli inviti gia' riscattati e mai premiati --------------
--
-- Chi ha usato un codice prima di questa migrazione e ha gia' il profilo
-- completo riceve adesso il premio che gli spettava.

do $$
declare
    r record;
begin
    perform set_config('brindoo.entitlement_grant', 'on', true);

    for r in
        select rr.id as redemption_id, rr.code_id, rr.redeemer_id, rc.user_id as inviter_id
          from public.referral_redemptions rr
          join public.referral_codes rc on rc.id = rr.code_id
          join public.profiles p on p.id = rr.redeemer_id
         where rr.reward_granted = false
           and rc.user_id <> rr.redeemer_id
           and public.brindoo_profile_is_complete(p)
    loop
        update public.referral_redemptions
           set reward_granted = true
         where id = r.redemption_id;

        update public.referral_codes
           set reward_granted_count = reward_granted_count + 1
         where id = r.code_id;

        perform public.brindoo_grant_pro_month(r.inviter_id);
        perform public.brindoo_grant_pro_month(r.redeemer_id);
    end loop;

    perform set_config('brindoo.entitlement_grant', 'off', true);
end;
$$;
