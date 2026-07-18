-- SyncNote Supabase schema
-- Run in Supabase SQL editor: Dashboard → SQL → paste + run

create extension if not exists "uuid-ossp";
create extension if not exists vector;

create table if not exists public.notes (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  title       text not null default '',
  body        text not null default '',
  kind        text not null default 'note' check (kind in ('note','link','file')),
  url         text,
  tags        text[] not null default '{}',
  folder      text,
  embedding   vector(1536),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists notes_user_updated_idx on public.notes (user_id, updated_at desc);
create index if not exists notes_tags_idx on public.notes using gin (tags);
create index if not exists notes_body_trgm_idx on public.notes using gin (body gin_trgm_ops);
create index if not exists notes_title_trgm_idx on public.notes using gin (title gin_trgm_ops);

create extension if not exists pg_trgm;

-- Row-level security: users only see their own notes.
alter table public.notes enable row level security;

drop policy if exists "read own"   on public.notes;
drop policy if exists "insert own" on public.notes;
drop policy if exists "update own" on public.notes;
drop policy if exists "delete own" on public.notes;

create policy "read own"   on public.notes for select using (auth.uid() = user_id);
create policy "insert own" on public.notes for insert with check (auth.uid() = user_id);
create policy "update own" on public.notes for update using (auth.uid() = user_id);
create policy "delete own" on public.notes for delete using (auth.uid() = user_id);

-- Enable realtime broadcasts on the notes table (for cross-device sync).
alter publication supabase_realtime add table public.notes;
