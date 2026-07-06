-- Tempo mediano di risposta in chat del professionista (minuti).
-- Auto-calcolato dall'app del professionista (al massimo 1 volta/giorno)
-- e mostrato ai clienti come "Risponde in giornata" su profilo e card.
-- Nullable: nessun dato = nessuna etichetta.

alter table public.profiles
  add column if not exists response_minutes integer;

comment on column public.profiles.response_minutes is
  'Tempo mediano di risposta in chat (minuti), aggiornato dall''app del professionista.';
