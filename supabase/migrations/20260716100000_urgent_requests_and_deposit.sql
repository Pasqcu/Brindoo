-- Nono giro: richieste urgenti (last-minute) e acconto versato.
--
-- client_requests.urgent: il cliente segnala che l'evento è vicino;
-- la richiesta risale in cima alla bacheca dei professionisti.
--
-- offer_proposals.deposit_paid: le parti registrano il versamento
-- dell'acconto su una trattativa accettata (aggiornabile da entrambe,
-- come booking_status, tramite le policy di update già esistenti).

alter table public.client_requests
  add column if not exists urgent boolean not null default false;

alter table public.offer_proposals
  add column if not exists deposit_paid boolean not null default false;
