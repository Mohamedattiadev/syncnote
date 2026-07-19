-- Adds a pinned flag to notes so users can star favorites.
alter table public.notes add column if not exists pinned boolean not null default false;
create index if not exists notes_pinned_idx on public.notes (user_id, pinned desc, updated_at desc);
