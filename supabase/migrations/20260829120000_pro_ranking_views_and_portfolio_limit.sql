-- =====================================================================
-- Il posto in cima si compra, quindi lo deve assegnare il database.
--
-- Tre buchi rimasti aperti dopo 20260812100000:
--
-- 1) L'ordinamento "Pro prima" viveva nell'app, DOPO aver scaricato una
--    pagina. Le richieste dei clienti arrivano con `limit(100)`: appena
--    le richieste aperte superano il centinaio, quella di un cliente Pro
--    piu' vecchia non entra nella pagina e il posto in evidenza che ha
--    pagato non esiste. Stessa cosa per la vetrina dei professionisti,
--    che ordinava sul flag `is_pro` — una cache che si spegne solo quando
--    passa il lavoro orario, e mai se pg_cron non c'e'.
--
-- 2) Il tetto di 5 foto del portfolio viveva solo nell'app iOS: parlando
--    direttamente con l'API se ne caricavano 50 senza abbonarsi. E' lo
--    stesso buco gia' chiuso per le offerte e per le richieste.
--
-- Le due viste usano `security_invoker = true`: le regole di accesso
-- restano quelle delle tabelle sotto, la vista non concede niente di piu'.
-- =====================================================================


-- 1) Vetrina professionisti -------------------------------------------
--
-- Espone due colonne calcolate al momento della lettura, cosi' PostgREST
-- puo' ordinarci sopra. Nessuna colonna esistente cambia: `select p.*`
-- lascia passare tutto quello che l'app gia' decodifica.

drop view if exists public.profiles_ranked;
create view public.profiles_ranked
with (security_invoker = true)
as
    select p.*,
           coalesce(p.boost_expires_at > now(), false) as boost_active,
           coalesce(p.pro_expires_at  > now(), false) as pro_active
      from public.profiles p;

comment on view public.profiles_ranked is
    'profiles + boost_active/pro_active calcolati adesso. Serve a ordinare la '
    'vetrina su un dato vero invece che sul flag is_pro, che e'' solo una cache.';

-- Il progetto concede da solo `select` ad `anon` sui nuovi oggetti di
-- `public`: va tolto a mano. La vista gira `security_invoker`, quindi non
-- mostrerebbe nulla in piu' delle regole di `profiles`, ma la lezione della
-- vista `client_trust_stats` vale lo stesso: niente endpoint regalati.
revoke all on public.profiles_ranked from anon;
grant select on public.profiles_ranked to authenticated;


-- 2) Bacheca richieste dei clienti ------------------------------------
--
-- `client_is_pro` dice se il cliente che ha pubblicato la richiesta e'
-- abbonato adesso. Serve solo a ordinare: chi guarda la bacheca non vede
-- nessun dato in piu' del cliente.

drop view if exists public.client_requests_ranked;
create view public.client_requests_ranked
with (security_invoker = true)
as
    select r.*,
           coalesce(pr.pro_expires_at > now(), false) as client_is_pro
      from public.client_requests r
      join public.profiles pr on pr.id = r.client_id;

comment on view public.client_requests_ranked is
    'client_requests + client_is_pro. Il posto in cima e'' un vantaggio Pro: '
    'va deciso qui, non riordinando a valle una pagina gia'' tagliata.';

revoke all on public.client_requests_ranked from anon;
grant select on public.client_requests_ranked to authenticated;


-- 3) Limite foto del portfolio ----------------------------------------
--
-- Il tetto e' del portfolio intero, foto e video insieme: e' la stessa
-- regola che applica `PortfolioService.ensureCapacity`.

create or replace function public.brindoo_enforce_portfolio_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    current_count integer;
    cap           integer;
begin
    cap := case
             when coalesce(public.brindoo_is_pro(new.organizer_id), false) then 50
             else 5
           end;

    select count(*) into current_count
      from public.portfolio_items i
     where i.organizer_id = new.organizer_id
       and i.id is distinct from new.id;

    if current_count >= cap then
        if cap = 5 then
            raise exception
                'Il piano gratuito permette 5 foto nel portfolio: passa a Brindoo Pro per averne fino a 50'
                using errcode = '42501';
        else
            raise exception 'Portfolio pieno: il massimo e'' % elementi', cap
                using errcode = '42501';
        end if;
    end if;

    return new;
end;
$$;

-- Postgres concede `execute` a PUBLIC su ogni funzione nuova: la funzione di
-- trigger non e' esposta da PostgREST, ma la revoca costa una riga.
revoke all on function public.brindoo_enforce_portfolio_limit() from public, anon, authenticated;

-- `portfolio_items` non nasce da queste migrazioni (storico divergente):
-- su un database ricostruito da zero la tabella puo' non esserci ancora.
do $$
begin
    if to_regclass('public.portfolio_items') is null then
        raise notice 'portfolio_items non esiste: limite portfolio NON installato.';
        return;
    end if;

    drop trigger if exists portfolio_items_enforce_free_limit on public.portfolio_items;
    create trigger portfolio_items_enforce_free_limit
        before insert on public.portfolio_items
        for each row
        execute function public.brindoo_enforce_portfolio_limit();
end$$;


-- Verifica leggibile nell'output del push.
do $$
begin
    if to_regclass('public.profiles_ranked') is null
       or to_regclass('public.client_requests_ranked') is null then
        raise exception 'Le viste di ordinamento non risultano create.';
    end if;
    raise notice 'OK: profiles_ranked e client_requests_ranked create.';

    if exists (select 1 from pg_trigger where tgname = 'portfolio_items_enforce_free_limit') then
        raise notice 'OK: limite portfolio installato.';
    else
        raise notice 'ATTENZIONE: limite portfolio NON installato.';
    end if;
end$$;
