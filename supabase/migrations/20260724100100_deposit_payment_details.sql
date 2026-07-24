-- Acconto e saldo: chi paga cosa, come, e con conferma dell'altra parte.
--
-- Prima l'acconto era una sola spunta ("versato sì/no") che chiunque poteva
-- mettere: nessun importo, nessun modo di pagamento, nessuna conferma.
-- Ora:
--   - si concorda il modo di pagamento (contanti alla consegna o tracciato)
--   - chi incassa dichiara l'importo ricevuto
--   - l'altra parte conferma: solo allora l'acconto risulta versato
--
-- Nessun pagamento passa dentro l'app: Brindoo registra l'accordo, i soldi
-- si scambiano fra le parti come hanno scelto.

alter table public.offer_proposals
  -- Come si è deciso di pagare: 'cash' = contanti, 'transfer' = bonifico
  -- o altro mezzo tracciato, 'other' = da concordare.
  add column if not exists deposit_method text
    check (deposit_method in ('cash', 'transfer', 'other')),
  add column if not exists balance_method text
    check (balance_method in ('cash', 'transfer', 'other')),
  add column if not exists deposit_amount numeric(10, 2)
    check (deposit_amount is null or deposit_amount >= 0),
  add column if not exists deposit_note text,
  -- Dichiarazione di chi incassa.
  add column if not exists deposit_declared_by uuid references public.profiles(id),
  add column if not exists deposit_declared_at timestamptz,
  -- Conferma dell'altra parte: è questa che rende l'acconto "versato".
  add column if not exists deposit_confirmed_by uuid references public.profiles(id),
  add column if not exists deposit_confirmed_at timestamptz;

-- Tiene allineata la vecchia spunta: resta vera solo ad acconto confermato,
-- così le schermate che la leggono continuano a funzionare.
create or replace function public.sync_deposit_paid()
returns trigger
language plpgsql
as $$
begin
  new.deposit_paid := new.deposit_confirmed_at is not null;
  return new;
end;
$$;

drop trigger if exists trg_sync_deposit_paid on public.offer_proposals;
create trigger trg_sync_deposit_paid
  before insert or update of deposit_confirmed_at on public.offer_proposals
  for each row execute function public.sync_deposit_paid();

-- Chi dichiara non può anche confermare: serve la controparte.
create or replace function public.check_deposit_confirmation()
returns trigger
language plpgsql
as $$
begin
  if new.deposit_confirmed_by is not null
     and new.deposit_confirmed_by = new.deposit_declared_by then
    raise exception 'La conferma dell''acconto deve arrivare dall''altra parte';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_check_deposit_confirmation on public.offer_proposals;
create trigger trg_check_deposit_confirmation
  before insert or update on public.offer_proposals
  for each row execute function public.check_deposit_confirmation();
