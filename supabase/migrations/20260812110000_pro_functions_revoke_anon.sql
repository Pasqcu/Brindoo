-- =====================================================================
-- Chiude l'accesso pubblico alle funzioni introdotte da
-- 20260812100000_pro_expiry_and_plan_limits.sql.
--
-- Postgres concede EXECUTE a PUBLIC su ogni nuova funzione, e il progetto
-- espone lo schema `public` via PostgREST: senza revoca esplicita
-- `brindoo_expire_pro()` diventava un endpoint di scrittura richiamabile
-- da chiunque abbia la chiave publishable — che viaggia dentro l'app.
-- Verificato subito dopo il deploy: POST /rest/v1/rpc/brindoo_expire_pro
-- con la sola apikey rispondeva 200.
--
-- Stessa lezione della vista `client_trust_stats`
-- (20260724110000_client_trust_revoke_anon.sql).
--
-- Nessuno dei due serve ai client: `brindoo_is_pro` la usano solo i trigger
-- di limite, che essendo `security definer` girano come proprietario.
-- =====================================================================

revoke all on function public.brindoo_expire_pro()      from public, anon, authenticated;
revoke all on function public.brindoo_is_pro(uuid)      from public, anon, authenticated;

-- Il cron gira come proprietario del job; la edge function usa service_role.
grant execute on function public.brindoo_expire_pro() to service_role;
grant execute on function public.brindoo_is_pro(uuid) to service_role;


-- Verifica dello scheduling: se pg_cron non e' installato su questo
-- progetto, la scadenza lato server non passa mai e resta solo il calcolo
-- lato app. Meglio saperlo dall'output del push che scoprirlo tra un mese.
do $$
declare
    has_cron boolean;
    has_job  boolean;
begin
    select exists (select 1 from pg_extension where extname = 'pg_cron') into has_cron;

    if not has_cron then
        raise notice 'ATTENZIONE: pg_cron non installato: brindoo_expire_pro NON e'' schedulata.';
        return;
    end if;

    execute 'select exists (select 1 from cron.job where jobname = ''brindoo_expire_pro'')'
        into has_job;

    if has_job then
        raise notice 'OK: brindoo_expire_pro schedulata ogni ora.';
    else
        raise notice 'ATTENZIONE: pg_cron c''e'' ma il job brindoo_expire_pro non risulta schedulato.';
    end if;
end$$;
