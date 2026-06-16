-- Stato dell'appuntamento dopo l'accettazione della trattativa.
-- Valori usati dall'app: confirmed | completed | cancelled (nullable).
alter table public.offer_proposals
    add column if not exists booking_status text;
