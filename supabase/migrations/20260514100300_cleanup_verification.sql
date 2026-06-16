-- =====================================================================
-- Cleanup: rimuove il flow di "Verifica identità" (admin-approved) che
-- non viene più usato. Il badge di trust è coperto dall'abbonamento Pro.
--
-- Cosa droppa:
--  - tabella verification_requests (e le sue policy/index, via CASCADE)
--  - colonna profiles.verified_at
--
-- Sicuro da rilanciare (IF EXISTS).
-- =====================================================================

drop table if exists public.verification_requests cascade;

alter table public.profiles
    drop column if exists verified_at;
