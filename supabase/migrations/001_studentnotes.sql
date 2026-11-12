
-- ================================================
-- STUDENTNOTES DATABASE
-- ================================================

create extension if not exists pgcrypto;

-- Extend existing profiles table

alter table public.profiles
add column if not exists college text,
add column if not exists department text,
add column if not exists semester integer,
add column if not exists is_admin boolean not null default false;

-- ================================================
-- NOTES TABLE
-- ================================================

create table if not exists public.notes (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references auth.users(id) on delete cascade,

    title text not null,
    description text,

    subject text not null,
    department text,
    semester integer not null check (semester between 1 and 12),

    file_path text not null unique,
    file_name text not null,
    file_size bigint not null,
    mime_type text not null default 'application/pdf',

    downloads integer not null default 0,
    status text not null default 'published'
        check (status in ('published', 'pending', 'rejected')),

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists notes_subject_idx
on public.notes(subject);

create index if not exists notes_semester_idx
on public.notes(semester);

create index if not exists notes_created_at_idx
on public.notes(created_at desc);

create index if not exists notes_user_id_idx
on public.notes(user_id);

-- ================================================
-- BOOKMARKS
-- ================================================

create table if not exists public.bookmarks (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references auth.users(id) on delete cascade,

    note_id uuid not null
        references public.notes(id) on delete cascade,

    created_at timestamptz not null default now(),

    unique(user_id, note_id)
);

-- ================================================
-- REVIEWS
-- ================================================

create table if not exists public.reviews (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references auth.users(id) on delete cascade,

    note_id uuid not null
        references public.notes(id) on delete cascade,

    rating integer not null check (rating between 1 and 5),
    comment text,

    created_at timestamptz not null default now(),

    unique(user_id, note_id)
);

-- ================================================
-- REPORTS
-- ================================================

create table if not exists public.reports (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references auth.users(id) on delete cascade,

    note_id uuid not null
        references public.notes(id) on delete cascade,

    reason text not null,
    details text,

    status text not null default 'pending'
        check (status in ('pending', 'reviewed', 'dismissed')),

    created_at timestamptz not null default now()
);

-- ================================================
-- ENABLE RLS
-- ================================================

alter table public.notes enable row level security;
alter table public.bookmarks enable row level security;
alter table public.reviews enable row level security;
alter table public.reports enable row level security;

-- ================================================
-- NOTES POLICIES
-- ================================================

drop policy if exists "Read published notes"
on public.notes;

create policy "Read published notes"
on public.notes
for select
to authenticated
using (
    status = 'published'
    or user_id = (select auth.uid())
    or exists (
        select 1 from public.profiles
        where id = (select auth.uid())
        and is_admin = true
    )
);

drop policy if exists "Upload own notes"
on public.notes;

create policy "Upload own notes"
on public.notes
for insert
to authenticated
with check (
    user_id = (select auth.uid())
);

drop policy if exists "Update own notes"
on public.notes;

create policy "Update own notes"
on public.notes
for update
to authenticated
using (
    user_id = (select auth.uid())
    or exists (
        select 1 from public.profiles
        where id = (select auth.uid())
        and is_admin = true
    )
)
with check (
    user_id = (select auth.uid())
    or exists (
        select 1 from public.profiles
        where id = (select auth.uid())
        and is_admin = true
    )
);

drop policy if exists "Delete own notes"
on public.notes;

create policy "Delete own notes"
on public.notes
for delete
to authenticated
using (
    user_id = (select auth.uid())
    or exists (
        select 1 from public.profiles
        where id = (select auth.uid())
        and is_admin = true
    )
);

-- ================================================
-- BOOKMARK POLICIES
-- ================================================

create policy "Users manage own bookmarks"
on public.bookmarks
for all
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- ================================================
-- REVIEW POLICIES
-- ================================================

create policy "Read reviews"
on public.reviews
for select
to authenticated
using (true);

create policy "Insert own reviews"
on public.reviews
for insert
to authenticated
with check (user_id = (select auth.uid()));

create policy "Update own reviews"
on public.reviews
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy "Delete own reviews"
on public.reviews
for delete
to authenticated
using (user_id = (select auth.uid()));

-- ================================================
-- REPORT POLICIES
-- ================================================

create policy "Insert own reports"
on public.reports
for insert
to authenticated
with check (user_id = (select auth.uid()));

create policy "Read own reports"
on public.reports
for select
to authenticated
using (
    user_id = (select auth.uid())
    or exists (
        select 1 from public.profiles
        where id = (select auth.uid())
        and is_admin = true
    )
);

create policy "Admin updates reports"
on public.reports
for update
to authenticated
using (
    exists (
        select 1 from public.profiles
        where id = (select auth.uid())
        and is_admin = true
    )
)
with check (
    exists (
        select 1 from public.profiles
        where id = (select auth.uid())
        and is_admin = true
    )
);

-- ================================================
-- STORAGE BUCKET
-- ================================================

insert into storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
)
values (
    'student-notes',
    'student-notes',
    false,
    20971520,
    array['application/pdf']
)
on conflict (id) do update
set
    public = false,
    file_size_limit = 20971520,
    allowed_mime_types = array['application/pdf'];

drop policy if exists "Students upload own PDFs"
on storage.objects;

create policy "Students upload own PDFs"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'student-notes'
    and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Students read own PDFs"
on storage.objects;

create policy "Students read own PDFs"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'student-notes'
    and (
        (storage.foldername(name))[1] = (select auth.uid())::text
        or exists (
            select 1
            from public.notes n
            where n.file_path = name
            and n.status = 'published'
        )
    )
);

drop policy if exists "Students delete own PDFs"
on storage.objects;

create policy "Students delete own PDFs"
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'student-notes'
    and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- ================================================
-- SECURE DOWNLOAD COUNTER
-- ================================================

create or replace function public.increment_note_downloads(
    p_note_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin

    if auth.uid() is null then
        raise exception 'Authentication required';
    end if;

    update public.notes
    set downloads = downloads + 1
    where id = p_note_id
      and status = 'published';

end;
$$;

revoke all on function public.increment_note_downloads(uuid)
from public, anon;

grant execute on function public.increment_note_downloads(uuid)
to authenticated;

