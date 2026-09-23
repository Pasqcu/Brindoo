-- =====================================================================
-- Da dove viene il Pro: abbonamento Apple e mesi regalati, tenuti separati.
--
-- Prima c'era una colonna sola, `pro_expires_at`, scritta da due mani:
-- la edge function `validate-iap-receipt` (scadenza Apple) e il premio del
-- codice invito (+1 mese). A ogni avvio l'app rimanda la transazione
-- attiva e la funzione riscriveva la scadenza Apple, cancellando il mese
-- regalato. Un rimborso la azzerava, portandosi via anche i mesi regalati.
--
-- Adesso:
--   iap_pro_expires_at    -> la scrive solo la edge function (Apple)
--   bonus_pro_expires_at  -> la scrive solo il premio invito
--   pro_expires_at        -> calcolata qui: la piu' lontana delle due.
-- L'app e le viste continuano a leggere `pro_expires_at`.
--
-- Regole del codice invito (decise il 2026-09-23):
--   * chi riceve l'invito ottiene un mese, una volta sola (gia' garantito
--     da `referral_redemptions.redeemer_id unique`), e solo nei primi
--     30 giorni dall'iscrizione: un codice e' per chi arriva, non uno
--     scambio fra account gia' esistenti;
--   * chi invita ottiene un mese per ogni amico, fino a 6 mesi in tutto:
--     con account finti non si accumula Pro senza limite;
--   * con un abbonamento attivo il mese regalato parte dopo il periodo gia'
--     pagato: se l'abbonamento viene disdetto, si resta Pro un mese in piu'.
-- =====================================================================

-- Le scritture di questa migrazione toccano colonne protette.
select set_config('brindoo.entitlement_grant', 'on', true);

alter table public.profiles add column if not exists iap_pro_expires_at   timestamptz;
alter table public.profiles add column if not exists bonus_pro_expires_at timestamptz;

comment on column public.profiles.iap_pro_expires_at is
    'Scadenza dell''abbonamento Apple. La scrive solo la edge function con service_role.';
comment on column public.profiles.bonus_pro_expires_at is
    'Fine dei mesi Pro regalati (codice invito). La scrive solo brindoo_grant_pro_month.';


-- 1) Recupero dello stato attuale ---------------------------------------

update public.profiles p
   set iap_pro_expires_at = s.expires_at
  from (select user_id, max(expires_date) as expires_at
          from public.purchases
         where is_subscription
         group by user_id) s
 where s.user_id = p.id
   and p.iap_pro_expires_at is distinct from s.expires_at;

-- Quello che l'abbonamento non spiega e' un regalo (invito o concessione a mano).
update public.profiles
   set bonus_pro_expires_at = pro_expires_at
 where pro_expires_at is not null
   and pro_expires_at > coalesce(iap_pro_expires_at, '-infinity'::timestamptz)
   and bonus_pro_expires_at is distinct from pro_expires_at;


-- 2) pro_expires_at e is_pro calcolati dalle due fonti --------------------

create or replace function public.brindoo_compute_pro_expiry()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    -- greatest() ignora i null: nessuna fonte = nessun Pro.
    new.pro_expires_at := greatest(new.iap_pro_expires_at, new.bonus_pro_expires_at);
    new.is_pro := coalesce(new.pro_expires_at > now(), false);
    return new;
end;
$$;

revoke all on function public.brindoo_compute_pro_expiry() from public, anon, authenticated;

drop trigger if exists profiles_compute_pro_expiry on public.profiles;
create trigger profiles_compute_pro_expiry
    before insert or update of iap_pro_expires_at, bonus_pro_expires_at on public.profiles
    for each row
    execute function public.brindoo_compute_pro_expiry();

-- Allinea subito le righe gia' esistenti alla regola nuova.
update public.profiles
   set pro_expires_at = greatest(iap_pro_expires_at, bonus_pro_expires_at)
 where pro_expires_at is distinct from greatest(iap_pro_expires_at, bonus_pro_expires_at);

-- Due trigger identici tenevano allineato is_pro: ne basta uno.
drop trigger if exists profiles_update_is_pro on public.profiles;
drop function if exists public.update_is_pro_from_expires();


-- 3) Le nuove colonne sono protette come le vecchie ------------------------

create or replace function public.profiles_block_client_entitlement_update()
returns trigger
language plpgsql
security definer
as $$
begin
    if auth.role() = 'service_role' then
        return new;
    end if;

    if coalesce(current_setting('brindoo.entitlement_grant', true), '') = 'on' then
        return new;
    end if;

    if new.pro_expires_at is distinct from old.pro_expires_at
       or new.iap_pro_expires_at is distinct from old.iap_pro_expires_at
       or new.bonus_pro_expires_at is distinct from old.bonus_pro_expires_at then
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


-- 4) Il mese regalato si somma, non sostituisce ----------------------------

create or replace function public.brindoo_grant_pro_month(target_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    -- Parte dalla data piu' lontana fra adesso, i mesi gia' regalati e il
    -- periodo gia' pagato ad Apple.
    update public.profiles
       set bonus_pro_expires_at =
               greatest(now(), bonus_pro_expires_at, iap_pro_expires_at) + interval '1 month'
     where id = target_id;
end;
$$;

-- Era eseguibile da chiunque via /rest/v1/rpc: il blocco sugli entitlement
-- la fermava, ma non deve essere un endpoint.
revoke all on function public.brindoo_grant_pro_month(uuid) from public, anon, authenticated;


-- 5) Premio invito con tetto per chi invita -------------------------------

create or replace function public.brindoo_referral_pay(
    p_redemption_id uuid,
    p_code_id       uuid,
    p_inviter_id    uuid,
    p_redeemer_id   uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    max_inviter_months constant integer := 6;
    v_earned integer;
begin
    -- Chiude il riscatto per primo: due aggiornamenti insieme non pagano due volte.
    update public.referral_redemptions
       set reward_granted = true
     where id = p_redemption_id
       and reward_granted = false;

    if not found then
        return;
    end if;

    perform set_config('brindoo.entitlement_grant', 'on', true);

    perform public.brindoo_grant_pro_month(p_redeemer_id);

    select reward_granted_count into v_earned
      from public.referral_codes
     where id = p_code_id
       for update;

    if coalesce(v_earned, 0) < max_inviter_months then
        update public.referral_codes
           set reward_granted_count = reward_granted_count + 1
         where id = p_code_id;
        perform public.brindoo_grant_pro_month(p_inviter_id);
    end if;

    perform set_config('brindoo.entitlement_grant', 'off', true);
end;
$$;

revoke all on function public.brindoo_referral_pay(uuid, uuid, uuid, uuid) from public, anon, authenticated;

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
    if public.brindoo_profile_is_complete(new) is not true then
        return new;
    end if;
    if tg_op = 'UPDATE' and public.brindoo_profile_is_complete(old) is true then
        return new;
    end if;

    select rr.id, rr.code_id, rc.user_id
      into v_redemption_id, v_code_id, v_inviter_id
      from public.referral_redemptions rr
      join public.referral_codes rc on rc.id = rr.code_id
     where rr.redeemer_id = new.id
       and rr.reward_granted = false
     limit 1;

    if v_redemption_id is null or v_inviter_id = new.id then
        return new;
    end if;

    perform public.brindoo_referral_pay(v_redemption_id, v_code_id, v_inviter_id, new.id);
    return new;
end;
$$;

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

    perform public.brindoo_referral_pay(new.id, new.code_id, v_inviter_id, new.redeemer_id);
    return new;
end;
$$;

revoke all on function public.brindoo_referral_grant_reward()   from public, anon, authenticated;
revoke all on function public.brindoo_referral_grant_on_redeem() from public, anon, authenticated;


-- 6) Chi puo' riscattare un codice ----------------------------------------

create or replace function public.brindoo_referral_check_redeem()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_owner      uuid;
    v_created_at timestamptz;
begin
    select user_id into v_owner from public.referral_codes where id = new.code_id;
    if v_owner = new.redeemer_id then
        raise exception 'Invito non valido: non puoi usare il tuo codice'
            using errcode = '42501';
    end if;

    select created_at into v_created_at from auth.users where id = new.redeemer_id;
    if v_created_at < now() - interval '30 days' then
        raise exception 'Invito non valido: il codice si usa entro 30 giorni dall''iscrizione'
            using errcode = '42501';
    end if;

    return new;
end;
$$;

revoke all on function public.brindoo_referral_check_redeem() from public, anon, authenticated;

drop trigger if exists brindoo_referral_check_redeem_trigger on public.referral_redemptions;
create trigger brindoo_referral_check_redeem_trigger
    before insert on public.referral_redemptions
    for each row
    execute function public.brindoo_referral_check_redeem();


-- 7) Acquisti: li scrive solo il server ------------------------------------

alter table public.purchases add column if not exists revoked_at timestamptz;

-- Un client poteva inserire righe di acquisto inventate. Nessuno le usa per
-- dare diritti, ma la tabella deve raccontare solo acquisti veri.
drop policy if exists "Utente registra i propri acquisti" on public.purchases;

create index if not exists purchases_original_transaction_idx
    on public.purchases(original_transaction_id);

select set_config('brindoo.entitlement_grant', 'off', true);

do $$
begin
    if exists (select 1 from pg_trigger where tgname = 'profiles_update_is_pro') then
        raise exception 'Trigger duplicato is_pro ancora presente';
    end if;
    raise notice 'OK: fonti Pro separate, regole invito installate.';
end$$;
