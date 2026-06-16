-- =====================================================================
-- Reports notifications — switch da current_setting() a Supabase Vault.
--
-- Motivo: su Supabase Cloud (hosted) l'utente postgres della SQL Editor
-- non ha più privilegi `ALTER DATABASE ... SET ...`, quindi il pattern
-- `current_setting('app.supabase_url')` non è applicabile.
--
-- Il Vault è l'API ufficiale Supabase per memorizzare secrets cifrate.
-- Le secrets si inseriscono via SQL Editor con:
--   select vault.create_secret('<value>', '<name>', '<description>');
--
-- Le secrets richieste sono:
--   - 'supabase_url'       valore: https://<project>.supabase.co
--   - 'service_role_key'   valore: la service_role JWT
-- =====================================================================

create or replace function public.notify_moderators_on_new_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    supabase_url text;
    service_key text;
    payload jsonb;
begin
    -- Legge le secrets dal Vault. Se mancano, registra notice e prosegue
    -- senza notificare (il report resta comunque salvato).
    begin
        select decrypted_secret into supabase_url
        from vault.decrypted_secrets
        where name = 'supabase_url'
        limit 1;

        select decrypted_secret into service_key
        from vault.decrypted_secrets
        where name = 'service_role_key'
        limit 1;
    exception when others then
        raise notice 'notify_moderators: Vault non accessibile, skip notifica';
        return new;
    end;

    if supabase_url is null or service_key is null then
        raise notice 'notify_moderators: secret supabase_url o service_role_key non presente nel Vault';
        return new;
    end if;

    payload := jsonb_build_object(
        'record', to_jsonb(new)
    );

    perform net.http_post(
        url     := supabase_url || '/functions/v1/notify-moderators',
        headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || service_key
        ),
        body    := payload
    );

    return new;
end;
$$;

comment on function public.notify_moderators_on_new_report() is
    'Notifica via Edge Function al team di moderazione quando arriva una '
    'nuova segnalazione. Legge le credenziali da Supabase Vault. '
    'Best-effort: in caso di errore o secrets mancanti il report viene '
    'comunque salvato.';
