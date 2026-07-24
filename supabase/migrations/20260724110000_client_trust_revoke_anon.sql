-- I conteggi di affidabilità del cliente non devono essere leggibili da
-- chi non ha fatto accesso.
--
-- Il progetto concede in automatico la lettura al ruolo `anon` sui nuovi
-- oggetti dello schema public: la sola `grant ... to authenticated` della
-- migrazione precedente non bastava a escluderlo. Qui la revoca è esplicita.

revoke all on public.client_trust_stats from anon;
grant select on public.client_trust_stats to authenticated;
