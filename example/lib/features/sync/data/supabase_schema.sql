-- Supabase Core PostgreSQL Schema Setup for Realbook
-- Enable UUID Generation
create extension if not exists "uuid-ossp";

-- 1. Books Sync Table
create table public.books (
  id text not null, -- Local book ID
  user_id uuid references auth.users not null,
  title text not null,
  author text not null,
  file_path text not null,
  cover_path text,
  format text not null,
  added_at timestamp with time zone default timezone('utc'::text, now()) not null,
  last_read_chapter_index integer default 0 not null,
  last_read_page_index integer default 0 not null,
  is_deleted boolean default false not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (user_id, id) -- Composite primary key to avoid inter-user ID conflicts
);

-- 2. Highlights Sync Table
create table public.highlights (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  book_id text not null,
  chapter_index integer not null,
  start_offset integer not null,
  end_offset integer not null,
  selected_text text not null,
  highlight_color text not null,
  note text,
  is_deleted boolean default false not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  constraint highlights_natural_key unique (user_id, book_id, chapter_index, start_offset) -- Prevents duplicate selections per user
);

-- 3. Bookmarks Sync Table
create table public.bookmarks (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  book_id text not null,
  chapter_index integer not null,
  page_index integer not null,
  label text not null,
  is_deleted boolean default false not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  constraint bookmarks_natural_key unique (user_id, book_id, chapter_index, page_index) -- Prevents duplicate bookmarks per page
);

-- 4. Enable Row-Level Security (RLS)
alter table public.books enable row level security;
alter table public.highlights enable row level security;
alter table public.bookmarks enable row level security;

-- 5. Performance Indices for Sync Queries
-- Composite index on (user_id, updated_at) enables narrow index scans for delta pull queries.
-- Without this, Postgres falls back to bitmap scans or sequential scans even with RLS filtering.
create index if not exists idx_books_user_updated on public.books (user_id, updated_at);
create index if not exists idx_highlights_user_updated on public.highlights (user_id, updated_at);
create index if not exists idx_bookmarks_user_updated on public.bookmarks (user_id, updated_at);

-- 6. Row-Level Security (RLS) Policies
-- Books Policies
create policy "Allow authenticated users full access to their own books"
  on public.books for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Highlights Policies
create policy "Allow authenticated users full access to their own highlights"
  on public.highlights for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Bookmarks Policies
create policy "Allow authenticated users full access to their own bookmarks"
  on public.bookmarks for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
