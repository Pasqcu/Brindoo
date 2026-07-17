-- Consenso legale con prova (GDPR, accountability):
-- data e versione dei Termini accettati + data della dichiarazione
-- di responsabilità del professionista. Scritti dall'app al momento
-- dell'accettazione; nullable per i profili esistenti (l'app ripropone
-- l'accettazione al primo avvio utile).

alter table public.profiles
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists terms_version text,
  add column if not exists professional_declaration_at timestamptz;
