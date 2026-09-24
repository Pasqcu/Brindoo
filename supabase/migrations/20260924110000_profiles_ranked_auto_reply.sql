-- La vetrina e la scheda del professionista leggono i profili da
-- `profiles_ranked`, che elenca le colonne a mano: senza queste quattro
-- l'app non sapeva che il professionista e' assente e in chat non
-- compariva la striscia "Non raggiungibile".
--
-- Le colonne nuove vanno in fondo (create or replace view non permette
-- altro) e l'opzione security_invoker va ripetuta: senza WITH verrebbe
-- tolta e la vista leggerebbe i profili con i permessi del proprietario.

create or replace view public.profiles_ranked
with (security_invoker = true)
as
select id,
    role,
    full_name,
    avatar_url,
    phone,
    city,
    bio,
    is_pro,
    created_at,
    updated_at,
    pro_expires_at,
    boost_expires_at,
    read_receipts_enabled,
    vacation_until,
    province,
    coverage_areas,
    response_minutes,
    faqs,
    identity_verified,
    terms_accepted_at,
    terms_version,
    professional_declaration_at,
    notify_messages,
    notify_negotiations,
    notify_reminders,
    coalesce(boost_expires_at > now(), false) as boost_active,
    coalesce(pro_expires_at > now(), false) as pro_active,
    auto_reply_enabled,
    auto_reply_message,
    auto_reply_from,
    auto_reply_until
from public.profiles p;

revoke all on public.profiles_ranked from anon;
