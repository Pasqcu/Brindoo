-- Foto dell'evento allegata alla recensione dal cliente (facoltativa).
-- Il file vive nel bucket storage `portfolio` sotto la cartella del cliente.

alter table public.reviews
  add column if not exists photo_url text;

comment on column public.reviews.photo_url is
  'URL pubblico della foto allegata dal cliente alla recensione.';
