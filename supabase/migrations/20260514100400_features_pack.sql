-- =====================================================================
-- Feature pack 14/05/2026:
--  (d) Reply-to-message:  nessuna modifica (replied_to_id esiste già)
--  (p) Modalità vacanza:  profiles.vacation_until
--
--  NOTE: in una versione precedente di questa migrazione veniva creato
--  anche il flow di "Verifica identità" (profiles.verified_at +
--  verification_requests). È stato rimosso perché in app il badge di
--  trust è già coperto dall'abbonamento Pro: chi è Pro è "verificato".
--  Vedi 20260514_cleanup_verification.sql per il drop delle colonne/tabella.
-- =====================================================================

-- (p) Modalità vacanza -----------------------------------------------

alter table public.profiles
    add column if not exists vacation_until date;

create or replace function public.profile_is_on_vacation(p_user_id uuid)
returns boolean
language sql stable
as $$
    select coalesce(
        (select vacation_until >= current_date from public.profiles where id = p_user_id),
        false
    );
$$;
