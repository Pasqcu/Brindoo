-- =====================================================================
-- Aggiunte (additive, non distruttive):
--   - service_offers.image_url   : foto di copertina dell'offerta
--   - offer_proposals.event_date : data dell'evento concordata in trattativa
--   - reviews.verified           : recensione legata a una trattativa conclusa
-- =====================================================================

-- 1) Foto di copertina dell'offerta
alter table public.service_offers
    add column if not exists image_url text;

-- 2) Data evento sulla trattativa
alter table public.offer_proposals
    add column if not exists event_date date;

-- 3) Recensioni verificate
alter table public.reviews
    add column if not exists verified boolean not null default false;
