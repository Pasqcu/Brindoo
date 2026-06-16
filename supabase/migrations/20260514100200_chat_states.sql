-- =====================================================================
-- Stati per-utente sulle conversazioni:
-- - "Fissa in alto" (pin)
-- - "Segna come da leggere" (mark unread manuale)
--
-- Segue lo stesso pattern delle colonne deleted_by_*_at già presenti:
-- una coppia di timestamp nullable per cliente e organizzatore.
-- =====================================================================

alter table public.conversations
    add column if not exists pinned_by_client_at         timestamptz,
    add column if not exists pinned_by_organizer_at      timestamptz,
    add column if not exists marked_unread_by_client_at  timestamptz,
    add column if not exists marked_unread_by_organizer_at timestamptz;

-- Indici per ordinare lato applicazione (pinned first, poi last_message_at).
create index if not exists conversations_client_pin_idx
    on public.conversations(client_id, pinned_by_client_at desc nulls last);

create index if not exists conversations_organizer_pin_idx
    on public.conversations(organizer_id, pinned_by_organizer_at desc nulls last);
