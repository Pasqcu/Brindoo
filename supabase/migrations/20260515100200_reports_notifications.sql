-- =====================================================================
-- Reports notifications (15/05/2026)
--
-- Quando arriva una nuova segnalazione il trigger AFTER INSERT chiama la
-- Edge Function `notify-moderators` via pg_net.http_post. La funzione
-- invia un'email al team di moderazione (Resend).
--
-- Inoltre crea una vista comoda `admin_pending_reports_view` da usare nella
-- dashboard Supabase (richiede service_role o accesso DB diretto).
--
-- PREREQUISITI:
--  - extension `pg_net` abilitata (Supabase Dashboard → Database → Extensions)
--  - Database setting `app.supabase_url` e `app.service_role_key` (vedi sotto)
--
-- COME APPLICARE LE SETTING (una tantum, dalla SQL Editor di Supabase):
--   alter database postgres set "app.supabase_url" = 'https://<project>.supabase.co';
--   alter database postgres set "app.service_role_key" = '<service_role_key>';
-- =====================================================================

create extension if not exists pg_net with schema extensions;

-- 1) Funzione che notifica i moderatori chiamando la Edge Function ------

create or replace function public.notify_moderators_on_new_report()
returns trigger
language plpgsql
security definer
as $$
declare
    supabase_url text;
    service_key text;
    payload jsonb;
begin
    -- Recupera le credenziali dai database settings. Se non configurate,
    -- silenzia l'errore: il report resta comunque salvato, e il moderatore
    -- può leggerlo dalla vista admin_pending_reports_view.
    begin
        supabase_url := current_setting('app.supabase_url');
        service_key  := current_setting('app.service_role_key');
    exception when others then
        raise notice 'notify_moderators: app.supabase_url / app.service_role_key non configurati, skip notifica';
        return new;
    end;

    if supabase_url is null or service_key is null then
        return new;
    end if;

    payload := jsonb_build_object(
        'record', to_jsonb(new)
    );

    perform net.http_post(
        url     := supabase_url || '/functions/v1/notify-moderators',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || service_key
        ),
        body    := payload
    );

    return new;
end;
$$;

drop trigger if exists reports_notify_moderators on public.reports;
create trigger reports_notify_moderators
    after insert on public.reports
    for each row
    execute function public.notify_moderators_on_new_report();

comment on function public.notify_moderators_on_new_report() is
    'Notifica via Edge Function al team di moderazione quando arriva una '
    'nuova segnalazione. Best-effort: in caso di errore o credenziali '
    'mancanti il report viene comunque salvato.';


-- 2) Vista admin per consultare i report pending ----------------------
--
-- Mostra ogni report pending con i dati essenziali del segnalante e (se
-- target_type = 'user') del segnalato. Non accessibile dai client (RLS
-- enabled, nessuna policy SELECT per i client). Si consulta come admin
-- dalla SQL Editor o tramite service_role.

create or replace view public.admin_pending_reports_view as
select
    r.id,
    r.created_at,
    r.target_type,
    r.target_id,
    r.reason,
    r.description,
    r.status,
    reporter.id            as reporter_id,
    reporter.full_name     as reporter_name,
    reporter.city          as reporter_city,
    target.full_name       as target_user_name,
    target.city            as target_user_city
from public.reports r
left join public.profiles reporter on reporter.id = r.reporter_id
left join public.profiles target
    on r.target_type = 'user' and target.id = r.target_id
where r.status = 'pending'
order by r.created_at desc;

comment on view public.admin_pending_reports_view is
    'Vista admin (consultabile solo via service_role o SQL Editor) con i '
    'report in stato pending arricchiti dai dati di reporter e target.';
