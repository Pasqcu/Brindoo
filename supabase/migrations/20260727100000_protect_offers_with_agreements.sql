-- ---------------------------------------------------------------------
-- Un'offerta con accordi confermati non si elimina.
--
-- `offer_proposals.offer_id` cancella a catena (`on delete cascade`).
-- Voleva dire che il professionista, riordinando il proprio catalogo,
-- poteva cancellare un'offerta vecchia e portarsi via anche gli accordi
-- gia' chiusi su quell'offerta: data dell'evento, prezzo pattuito,
-- acconto dichiarato e confermato. Spariva la traccia scritta di un
-- impegno preso con un cliente, e la finestra di conferma parlava solo
-- di "azione non annullabile".
--
-- Da qui in avanti il database rifiuta la cancellazione finche' esiste
-- almeno un accordo accettato e non annullato. Le trattative ancora
-- aperte o gia' rifiutate non bloccano nulla: non sono impegni presi.
-- ---------------------------------------------------------------------

create or replace function public.service_offers_block_delete_with_agreements()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_count int;
begin
    select count(*)
      into v_count
      from public.offer_proposals p
     where p.offer_id = old.id
       and p.status = 'accepted'
       and coalesce(p.booking_status, 'confirmed') <> 'cancelled';

    if v_count > 0 then
        raise exception
            'Questa offerta ha % accordi confermati e non puo'' essere eliminata.', v_count
            using errcode = '23503';  -- foreign_key_violation
    end if;

    return old;
end;
$$;

comment on function public.service_offers_block_delete_with_agreements() is
    'Impedisce di cancellare un''offerta che ha accordi accettati e non '
    'annullati: la cancellazione a catena porterebbe via prezzo, data e '
    'acconto di impegni gia'' presi con i clienti.';

drop trigger if exists service_offers_block_delete_trigger on public.service_offers;
create trigger service_offers_block_delete_trigger
    before delete on public.service_offers
    for each row
    execute function public.service_offers_block_delete_with_agreements();
