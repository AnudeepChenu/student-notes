
#!/usr/bin/env bash

set -euo pipefail

echo "========================================"
echo "       STUDENTNOTES SETUP"
echo "========================================"

# ------------------------------------------------
# 1. Validate project
# ------------------------------------------------

if [ ! -f package.json ]; then
  echo "ERROR: Run this script from student-notes root."
  exit 1
fi

if [ ! -f src/lib/supabase/server.ts ] || [ ! -f src/lib/supabase/client.ts ]; then
  echo "ERROR: Existing Supabase client files are missing."
  echo "Complete the authentication setup first."
  exit 1
fi

mkdir -p \
  src/app/api/notes/\[id\]/download \
  src/app/api/notes/\[id\]/review \
  src/app/api/notes/\[id\]/report \
  src/app/dashboard \
  src/app/notes \
  src/app/upload \
  src/app/bookmarks \
  src/app/profile \
  src/components/notes \
  src/components/profile \
  supabase/migrations

# ------------------------------------------------
# 2. Install dependencies
# ------------------------------------------------

echo "Installing dependencies..."

npm install lucide-react @supabase/supabase-js @supabase/ssr

# ------------------------------------------------
# 3. Database migration
# ------------------------------------------------

cat > supabase/migrations/001_studentnotes.sql <<'SQL'

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

SQL

echo "Database migration generated."

# ------------------------------------------------
# 4. Upload component
# ------------------------------------------------

cat > src/components/notes/UploadForm.tsx <<'TSX'

"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Upload, FileText } from "lucide-react";
import { createClient } from "@/lib/supabase/client";

export default function UploadForm() {
  const router = useRouter();
  const supabase = createClient();

  const [file, setFile] = useState<File | null>(null);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [subject, setSubject] = useState("");
  const [department, setDepartment] = useState("CSE");
  const [semester, setSemester] = useState("1");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");

  async function handleUpload(e: React.FormEvent) {
    e.preventDefault();
    setMessage("");

    if (!file || file.type !== "application/pdf") {
      setMessage("Please select a valid PDF file.");
      return;
    }

    if (file.size > 20 * 1024 * 1024) {
      setMessage("Maximum file size is 20 MB.");
      return;
    }

    if (!title.trim() || !subject.trim()) {
      setMessage("Title and subject are required.");
      return;
    }

    setLoading(true);

    try {
      const {
        data: { user },
        error: authError,
      } = await supabase.auth.getUser();

      if (authError || !user) {
        throw new Error("Please login before uploading.");
      }

      const filePath =
        `${user.id}/${crypto.randomUUID()}.pdf`;

      const { error: storageError } = await supabase.storage
        .from("student-notes")
        .upload(filePath, file, {
          contentType: "application/pdf",
          upsert: false,
        });

      if (storageError) throw storageError;

      const { error: databaseError } = await supabase
        .from("notes")
        .insert({
          user_id: user.id,
          title: title.trim(),
          description: description.trim(),
          subject: subject.trim(),
          department,
          semester: Number(semester),
          file_path: filePath,
          file_name: file.name,
          file_size: file.size,
          mime_type: "application/pdf",
          status: "published",
        });

      if (databaseError) {
        await supabase.storage
          .from("student-notes")
          .remove([filePath]);

        throw databaseError;
      }

      setMessage("Notes uploaded successfully!");

      setFile(null);
      setTitle("");
      setDescription("");
      setSubject("");

      router.refresh();

      setTimeout(() => {
        router.push("/notes");
      }, 1000);

    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : "Upload failed."
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <form
      onSubmit={handleUpload}
      className="bg-white border border-gray-200 rounded-2xl p-6 max-w-2xl space-y-6"
    >
      <div>
        <label className="block text-sm font-medium mb-2">
          Note title
        </label>

        <input
          required
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="e.g. Operating Systems Unit 1"
          className="w-full border rounded-xl p-3 text-sm"
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-2">
          Description
        </label>

        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Describe the contents..."
          rows={3}
          className="w-full border rounded-xl p-3 text-sm"
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-2">
          Subject
        </label>

        <input
          required
          value={subject}
          onChange={(e) => setSubject(e.target.value)}
          placeholder="e.g. Database Management Systems"
          className="w-full border rounded-xl p-3 text-sm"
        />
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium mb-2">
            Department
          </label>

          <select
            value={department}
            onChange={(e) => setDepartment(e.target.value)}
            className="w-full border rounded-xl p-3 text-sm"
          >
            {["CSE", "ECE", "EEE", "IT", "Mechanical", "Civil", "Other"].map(
              (item) => (
                <option key={item}>{item}</option>
              )
            )}
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium mb-2">
            Semester
          </label>

          <select
            value={semester}
            onChange={(e) => setSemester(e.target.value)}
            className="w-full border rounded-xl p-3 text-sm"
          >
            {Array.from({ length: 12 }, (_, i) => i + 1).map(
              (item) => (
                <option key={item} value={item}>
                  Semester {item}
                </option>
              )
            )}
          </select>
        </div>
      </div>

      <label className="block border-2 border-dashed border-gray-300 rounded-xl p-8 text-center cursor-pointer hover:bg-gray-50">
        {file ? (
          <>
            <FileText size={30} className="mx-auto text-indigo-600" />
            <p className="mt-3 font-medium text-sm">{file.name}</p>
            <p className="text-xs text-gray-400 mt-1">
              {(file.size / 1024 / 1024).toFixed(2)} MB
            </p>
          </>
        ) : (
          <>
            <Upload size={30} className="mx-auto text-indigo-600" />
            <p className="mt-3 font-medium text-sm">
              Select PDF document
            </p>
            <p className="text-xs text-gray-400 mt-1">
              Maximum file size: 20 MB
            </p>
          </>
        )}

        <input
          type="file"
          accept="application/pdf,.pdf"
          className="hidden"
          onChange={(e) => setFile(e.target.files?.[0] || null)}
        />
      </label>

      {message && (
        <p role="status" className="text-sm text-indigo-600">
          {message}
        </p>
      )}

      <button
        disabled={loading}
        className="w-full bg-indigo-600 text-white rounded-xl p-3 font-medium disabled:opacity-50"
      >
        {loading ? "Uploading..." : "Upload Notes"}
      </button>
    </form>
  );
}

TSX

# ------------------------------------------------
# 5. Upload page
# ------------------------------------------------

cat > src/app/upload/page.tsx <<'TSX'

import DashboardLayout from "@/components/layout/DashboardLayout";
import UploadForm from "@/components/notes/UploadForm";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function UploadPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  return (
    <DashboardLayout>
      <h1 className="text-2xl font-bold">Upload Notes</h1>

      <p className="text-sm text-gray-500 mt-2 mb-8">
        Share useful academic resources with other students.
      </p>

      <UploadForm />
    </DashboardLayout>
  );
}

TSX

# ------------------------------------------------
# 6. Notes explorer
# ------------------------------------------------

cat > src/components/notes/NotesExplorer.tsx <<'TSX'

"use client";

import { useMemo, useState } from "react";
import { Search, Download, Bookmark, FileText } from "lucide-react";
import { createClient } from "@/lib/supabase/client";

interface Note {
  id: string;
  title: string;
  description: string | null;
  subject: string;
  semester: number;
  department: string | null;
  downloads: number;
  file_name: string;
  created_at: string;
  user_id: string;
}

export default function NotesExplorer({
  notes,
  userId,
  initialBookmarks,
}: {
  notes: Note[];
  userId: string;
  initialBookmarks: string[];
}) {
  const supabase = createClient();

  const [search, setSearch] = useState("");
  const [semester, setSemester] = useState("all");
  const [department, setDepartment] = useState("all");
  const [sort, setSort] = useState("recent");
  const [bookmarks, setBookmarks] = useState(initialBookmarks);
  const [busyId, setBusyId] = useState("");

  const filtered = useMemo(() => {
    let result = notes.filter((note) => {
      const text = `${note.title} ${note.subject} ${note.description || ""}`;

      return (
        text.toLowerCase().includes(search.toLowerCase()) &&
        (semester === "all" || String(note.semester) === semester) &&
        (department === "all" || note.department === department)
      );
    });

    if (sort === "popular") {
      result = [...result].sort((a, b) => b.downloads - a.downloads);
    } else {
      result = [...result].sort(
        (a, b) =>
          new Date(b.created_at).getTime() -
          new Date(a.created_at).getTime()
      );
    }

    return result;
  }, [notes, search, semester, department, sort]);

  async function toggleBookmark(noteId: string) {
    if (busyId) return;

    setBusyId(noteId);

    const exists = bookmarks.includes(noteId);

    try {
      if (exists) {
        const { error } = await supabase
          .from("bookmarks")
          .delete()
          .eq("note_id", noteId)
          .eq("user_id", userId);

        if (error) throw error;

        setBookmarks((old) => old.filter((id) => id !== noteId));
      } else {
        const { error } = await supabase
          .from("bookmarks")
          .insert({
            note_id: noteId,
            user_id: userId,
          });

        if (error) throw error;

        setBookmarks((old) => [...old, noteId]);
      }
    } catch (error) {
      alert(error instanceof Error ? error.message : "Bookmark failed.");
    } finally {
      setBusyId("");
    }
  }

  async function downloadNote(noteId: string) {
    try {
      const response = await fetch(`/api/notes/${noteId}/download`);

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || "Download failed.");
      }

      window.open(data.url, "_blank", "noopener,noreferrer");
    } catch (error) {
      alert(error instanceof Error ? error.message : "Download failed.");
    }
  }

  return (
    <>
      <div className="bg-white border border-gray-200 rounded-xl p-3 flex items-center gap-3">
        <Search size={19} className="text-gray-400" />

        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search notes, subjects or topics..."
          className="flex-1 outline-none text-sm"
        />
      </div>

      <div className="flex flex-wrap gap-3 mt-5">
        <select
          value={semester}
          onChange={(e) => setSemester(e.target.value)}
          className="border bg-white rounded-xl p-3 text-sm"
        >
          <option value="all">All semesters</option>
          {Array.from({ length: 12 }, (_, i) => i + 1).map((n) => (
            <option key={n} value={n}>
              Semester {n}
            </option>
          ))}
        </select>

        <select
          value={department}
          onChange={(e) => setDepartment(e.target.value)}
          className="border bg-white rounded-xl p-3 text-sm"
        >
          <option value="all">All departments</option>
          {["CSE", "ECE", "EEE", "IT", "Mechanical", "Civil", "Other"].map(
            (item) => (
              <option key={item}>{item}</option>
            )
          )}
        </select>

        <select
          value={sort}
          onChange={(e) => setSort(e.target.value)}
          className="border bg-white rounded-xl p-3 text-sm"
        >
          <option value="recent">Recently added</option>
          <option value="popular">Most downloaded</option>
        </select>
      </div>

      <p className="text-sm text-gray-500 mt-6 mb-4">
        {filtered.length} notes found
      </p>

      {filtered.length === 0 ? (
        <div className="bg-white border rounded-2xl p-16 text-center">
          <FileText size={36} className="mx-auto text-gray-300" />
          <h2 className="font-semibold mt-4">No notes found</h2>
          <p className="text-sm text-gray-400 mt-2">
            Try changing your search or filters.
          </p>
        </div>
      ) : (
        <div className="grid sm:grid-cols-2 xl:grid-cols-3 gap-5">
          {filtered.map((note) => (
            <article
              key={note.id}
              className="bg-white border border-gray-100 rounded-2xl p-5 hover:shadow-md transition"
            >
              <div className="flex justify-between">
                <div className="w-11 h-11 rounded-xl bg-red-50 text-red-500 flex items-center justify-center">
                  <FileText size={22} />
                </div>

                <button
                  aria-label="Toggle bookmark"
                  disabled={busyId === note.id}
                  onClick={() => toggleBookmark(note.id)}
                >
                  <Bookmark
                    size={20}
                    className={
                      bookmarks.includes(note.id)
                        ? "fill-indigo-600 text-indigo-600"
                        : "text-gray-400"
                    }
                  />
                </button>
              </div>

              <h3 className="font-semibold mt-5 line-clamp-2">
                {note.title}
              </h3>

              <p className="text-sm text-gray-500 mt-2">
                {note.subject}
              </p>

              <p className="text-xs text-gray-400 mt-2">
                {note.department || "General"} · Semester {note.semester}
              </p>

              {note.description && (
                <p className="text-sm text-gray-500 mt-3 line-clamp-2">
                  {note.description}
                </p>
              )}

              <div className="flex justify-between items-center mt-5 pt-4 border-t">
                <span className="text-xs text-gray-400">
                  {note.downloads} downloads
                </span>

                <button
                  onClick={() => downloadNote(note.id)}
                  className="bg-indigo-600 text-white rounded-lg px-3 py-2 text-xs flex items-center gap-2"
                >
                  <Download size={14} />
                  Download
                </button>
              </div>
            </article>
          ))}
        </div>
      )}
    </>
  );
}

TSX

# ------------------------------------------------
# 7. Secure download API
# ------------------------------------------------

cat > src/app/api/notes/\[id\]/download/route.ts <<'TSX'

import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;

    const supabase = await createClient();

    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json(
        { error: "Authentication required." },
        { status: 401 }
      );
    }

    const { data: note, error } = await supabase
      .from("notes")
      .select("id, file_path, status")
      .eq("id", id)
      .maybeSingle();

    if (error || !note) {
      return NextResponse.json(
        { error: "Note not found." },
        { status: 404 }
      );
    }

    if (
      note.status !== "published" &&
      note.status !== undefined
    ) {
      return NextResponse.json(
        { error: "This note is not available." },
        { status: 403 }
      );
    }

    const { data: signed, error: signedError } =
      await supabase.storage
        .from("student-notes")
        .createSignedUrl(note.file_path, 300);

    if (signedError || !signed) {
      return NextResponse.json(
        { error: "Unable to access document." },
        { status: 500 }
      );
    }

    const { error: counterError } = await supabase.rpc(
      "increment_note_downloads",
      { p_note_id: note.id }
    );

    if (counterError) {
      console.error("Download counter error:", counterError);
    }

    return NextResponse.json({
      url: signed.signedUrl,
    });

  } catch (error) {
    console.error(error);

    return NextResponse.json(
      { error: "Unexpected server error." },
      { status: 500 }
    );
  }
}

TSX

# ------------------------------------------------
# 8. Notes page
# ------------------------------------------------

cat > src/app/notes/page.tsx <<'TSX'

import DashboardLayout from "@/components/layout/DashboardLayout";
import NotesExplorer from "@/components/notes/NotesExplorer";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function NotesPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const { data: notes } = await supabase
    .from("notes")
    .select("*")
    .eq("status", "published")
    .order("created_at", { ascending: false })
    .limit(100);

  const { data: saved } = await supabase
    .from("bookmarks")
    .select("note_id")
    .eq("user_id", user.id);

  return (
    <DashboardLayout>
      <h1 className="text-2xl font-bold">Explore Notes</h1>

      <p className="text-sm text-gray-500 mt-2 mb-7">
        Discover academic materials shared by students.
      </p>

      <NotesExplorer
        notes={notes || []}
        userId={user.id}
        initialBookmarks={(saved || []).map((item) => item.note_id)}
      />
    </DashboardLayout>
  );
}

TSX

# ------------------------------------------------
# 9. Bookmarks page
# ------------------------------------------------

cat > src/app/bookmarks/page.tsx <<'TSX'

import DashboardLayout from "@/components/layout/DashboardLayout";
import NotesExplorer from "@/components/notes/NotesExplorer";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function BookmarksPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const { data: saved } = await supabase
    .from("bookmarks")
    .select("note_id")
    .eq("user_id", user.id);

  const ids = (saved || []).map((item) => item.note_id);

  let notes: any[] = [];

  if (ids.length > 0) {
    const { data } = await supabase
      .from("notes")
      .select("*")
      .in("id", ids)
      .eq("status", "published");

    notes = data || [];
  }

  return (
    <DashboardLayout>
      <h1 className="text-2xl font-bold">My Bookmarks</h1>

      <p className="text-sm text-gray-500 mt-2 mb-7">
        Your saved academic resources.
      </p>

      <NotesExplorer
        notes={notes}
        userId={user.id}
        initialBookmarks={ids}
      />
    </DashboardLayout>
  );
}

TSX

# ------------------------------------------------
# 10. Profile editing component
# ------------------------------------------------

cat > src/components/profile/ProfileForm.tsx <<'TSX'

"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { useRouter } from "next/navigation";

interface Profile {
  full_name: string;
  college: string | null;
  department: string | null;
  semester: number | null;
}

export default function ProfileForm({
  profile,
}: {
  profile: Profile;
}) {
  const supabase = createClient();
  const router = useRouter();

  const [name, setName] = useState(profile.full_name || "");
  const [college, setCollege] = useState(profile.college || "");
  const [department, setDepartment] = useState(profile.department || "");
  const [semester, setSemester] = useState(
    String(profile.semester || 1)
  );

  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");

  async function saveProfile(e: React.FormEvent) {
    e.preventDefault();

    setLoading(true);
    setMessage("");

    try {
      const {
        data: { user },
      } = await supabase.auth.getUser();

      if (!user) throw new Error("Login required.");

      const { error } = await supabase
        .from("profiles")
        .update({
          full_name: name.trim(),
          college: college.trim(),
          department,
          semester: Number(semester),
          updated_at: new Date().toISOString(),
        })
        .eq("id", user.id);

      if (error) throw error;

      setMessage("Profile updated successfully.");
      router.refresh();

    } catch (error) {
      setMessage(
        error instanceof Error ? error.message : "Update failed."
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <form
      onSubmit={saveProfile}
      className="bg-white border border-gray-100 rounded-2xl p-7 max-w-xl space-y-5"
    >
      <div>
        <label className="text-sm font-medium">Full name</label>
        <input
          required
          value={name}
          onChange={(e) => setName(e.target.value)}
          className="w-full border rounded-xl p-3 mt-2 text-sm"
        />
      </div>

      <div>
        <label className="text-sm font-medium">College</label>
        <input
          value={college}
          onChange={(e) => setCollege(e.target.value)}
          placeholder="Your college"
          className="w-full border rounded-xl p-3 mt-2 text-sm"
        />
      </div>

      <div>
        <label className="text-sm font-medium">Department</label>
        <select
          value={department}
          onChange={(e) => setDepartment(e.target.value)}
          className="w-full border rounded-xl p-3 mt-2 text-sm"
        >
          <option value="">Select department</option>
          {["CSE", "ECE", "EEE", "IT", "Mechanical", "Civil", "Other"].map(
            (item) => (
              <option key={item}>{item}</option>
            )
          )}
        </select>
      </div>

      <div>
        <label className="text-sm font-medium">Semester</label>
        <select
          value={semester}
          onChange={(e) => setSemester(e.target.value)}
          className="w-full border rounded-xl p-3 mt-2 text-sm"
        >
          {Array.from({ length: 12 }, (_, i) => i + 1).map(
            (item) => (
              <option key={item} value={item}>
                Semester {item}
              </option>
            )
          )}
        </select>
      </div>

      {message && (
        <p role="status" className="text-sm text-indigo-600">
          {message}
        </p>
      )}

      <button
        disabled={loading}
        className="bg-indigo-600 text-white px-6 py-3 rounded-xl text-sm disabled:opacity-50"
      >
        {loading ? "Saving..." : "Save Profile"}
      </button>
    </form>
  );
}

TSX

# ------------------------------------------------
# 11. Profile page
# ------------------------------------------------

cat > src/app/profile/page.tsx <<'TSX'

import DashboardLayout from "@/components/layout/DashboardLayout";
import ProfileForm from "@/components/profile/ProfileForm";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function ProfilePage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .single();

  if (!profile) {
    return (
      <DashboardLayout>
        <p>Profile not found. Please contact support.</p>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout>
      <h1 className="text-2xl font-bold">My Profile</h1>

      <p className="text-sm text-gray-500 mt-2 mb-8">
        Manage your academic information.
      </p>

      <div className="mb-6">
        <p className="font-medium">{user.email}</p>
        <p className="text-xs text-gray-400 mt-1">
          Registered email address
        </p>
      </div>

      <ProfileForm profile={profile} />
    </DashboardLayout>
  );
}

TSX

# ------------------------------------------------
# 12. Dashboard
# ------------------------------------------------

cat > src/app/dashboard/page.tsx <<'TSX'

import DashboardLayout from "@/components/layout/DashboardLayout";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import Link from "next/link";
import {
  BookOpen,
  Download,
  Bookmark,
  Upload,
  ArrowRight,
} from "lucide-react";

export default async function Dashboard() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const { count: uploads } = await supabase
    .from("notes")
    .select("*", { count: "exact", head: true })
    .eq("user_id", user.id);

  const { data: notes } = await supabase
    .from("notes")
    .select("downloads")
    .eq("user_id", user.id);

  const { count: bookmarks } = await supabase
    .from("bookmarks")
    .select("*", { count: "exact", head: true })
    .eq("user_id", user.id);

  const { data: recent } = await supabase
    .from("notes")
    .select("id,title,subject,semester,created_at")
    .eq("status", "published")
    .order("created_at", { ascending: false })
    .limit(5);

  const totalDownloads = (notes || []).reduce(
    (sum, note) => sum + (note.downloads || 0),
    0
  );

  const stats = [
    { label: "My Uploads", value: uploads || 0, icon: Upload },
    { label: "Downloads of my notes", value: totalDownloads, icon: Download },
    { label: "Bookmarks", value: bookmarks || 0, icon: Bookmark },
  ];

  return (
    <DashboardLayout>
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold">Dashboard</h1>
          <p className="text-sm text-gray-500 mt-2">
            Welcome back, {user.user_metadata?.full_name || "Student"}.
          </p>
        </div>

        <Link
          href="/upload"
          className="bg-indigo-600 text-white rounded-xl px-5 py-3 text-sm flex items-center justify-center gap-2"
        >
          <Upload size={17} />
          Upload Notes
        </Link>
      </div>

      <div className="grid sm:grid-cols-2 xl:grid-cols-3 gap-5 mt-9">
        {stats.map((item) => {
          const Icon = item.icon;

          return (
            <div
              key={item.label}
              className="bg-white border border-gray-100 rounded-2xl p-6"
            >
              <div className="flex justify-between">
                <p className="text-sm text-gray-500">{item.label}</p>
                <Icon size={20} className="text-indigo-600" />
              </div>

              <h2 className="text-3xl font-bold mt-5">
                {item.value}
              </h2>
            </div>
          );
        })}
      </div>

      <section className="mt-10 bg-white border border-gray-100 rounded-2xl p-6">
        <div className="flex justify-between items-center mb-6">
          <h2 className="font-semibold text-lg">Recently uploaded notes</h2>
          <Link
            href="/notes"
            className="text-indigo-600 text-sm flex items-center gap-2"
          >
            Explore <ArrowRight size={15} />
          </Link>
        </div>

        {!recent?.length ? (
          <div className="text-center py-12">
            <BookOpen className="mx-auto text-gray-300" size={35} />
            <p className="font-medium mt-4">No notes available yet</p>
          </div>
        ) : (
          <div className="divide-y">
            {recent.map((note) => (
              <div
                key={note.id}
                className="py-4 flex justify-between items-center gap-3"
              >
                <div>
                  <p className="font-medium text-sm">{note.title}</p>
                  <p className="text-xs text-gray-400 mt-1">
                    {note.subject} · Semester {note.semester}
                  </p>
                </div>
                <BookOpen size={19} className="text-indigo-500" />
              </div>
            ))}
          </div>
        )}
      </section>
    </DashboardLayout>
  );
}

TSX

# ------------------------------------------------
# 13. Add review and reporting APIs
# ------------------------------------------------

cat > src/app/api/notes/\[id\]/review/route.ts <<'TSX'

import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const body = await request.json();

    const rating = Number(body.rating);
    const comment = typeof body.comment === "string"
      ? body.comment.trim().slice(0, 2000)
      : null;

    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      return NextResponse.json(
        { error: "Rating must be between 1 and 5." },
        { status: 400 }
      );
    }

    const supabase = await createClient();

    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json(
        { error: "Login required." },
        { status: 401 }
      );
    }

    const { error } = await supabase
      .from("reviews")
      .upsert(
        {
          note_id: id,
          user_id: user.id,
          rating,
          comment,
        },
        { onConflict: "user_id,note_id" }
      );

    if (error) throw error;

    return NextResponse.json({ success: true });

  } catch (error) {
    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : "Review failed.",
      },
      { status: 400 }
    );
  }
}

TSX

cat > src/app/api/notes/\[id\]/report/route.ts <<'TSX'

import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

const allowedReasons = [
  "Incorrect content",
  "Copyright concern",
  "Spam",
  "Inappropriate content",
  "Other",
];

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const body = await request.json();

    if (!allowedReasons.includes(body.reason)) {
      return NextResponse.json(
        { error: "Invalid report reason." },
        { status: 400 }
      );
    }

    const supabase = await createClient();

    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json(
        { error: "Login required." },
        { status: 401 }
      );
    }

    const { error } = await supabase
      .from("reports")
      .insert({
        note_id: id,
        user_id: user.id,
        reason: body.reason,
        details:
          typeof body.details === "string"
            ? body.details.trim().slice(0, 2000)
            : null,
      });

    if (error) throw error;

    return NextResponse.json({ success: true });

  } catch (error) {
    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : "Report failed.",
      },
      { status: 400 }
    );
  }
}

TSX

# ------------------------------------------------
# 14. Add a basic admin moderation page
# ------------------------------------------------

mkdir -p src/app/admin

cat > src/app/admin/page.tsx <<'TSX'

import DashboardLayout from "@/components/layout/DashboardLayout";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function AdminPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .single();

  if (!profile?.is_admin) redirect("/dashboard");

  const { data: reports } = await supabase
    .from("reports")
    .select("id,reason,details,status,created_at,note_id,user_id")
    .eq("status", "pending")
    .order("created_at", { ascending: false });

  return (
    <DashboardLayout>
      <h1 className="text-2xl font-bold">Content Moderation</h1>
      <p className="text-sm text-gray-500 mt-2 mb-8">
        Review reports submitted by students.
      </p>

      {!reports?.length ? (
        <div className="bg-white border rounded-2xl p-12 text-center">
          No pending reports.
        </div>
      ) : (
        <div className="space-y-4">
          {reports.map((report) => (
            <div
              key={report.id}
              className="bg-white border rounded-2xl p-5"
            >
              <p className="font-semibold">{report.reason}</p>
              <p className="text-sm text-gray-500 mt-2">
                {report.details || "No additional details"}
              </p>
              <p className="text-xs text-gray-400 mt-3">
                Note ID: {report.note_id}
              </p>
              <p className="text-xs text-gray-400">
                Report ID: {report.id}
              </p>
              <p className="text-xs text-gray-400 mt-1">
                Submitted by: {report.user_id}
              </p>
            </div>
          ))}
        </div>
      )}
    </DashboardLayout>
  );
}

TSX

# ------------------------------------------------
# 15. Add admin link to sidebar
# ------------------------------------------------

echo ""
echo "Core application files generated."
echo ""
echo "========================================"
echo "        SETUP FILES CREATED"
echo "========================================"
echo ""
echo "IMPORTANT NEXT STEPS:"
echo ""
echo "1. Review supabase/migrations/001_studentnotes.sql"
echo "2. Execute the SQL migration in Supabase SQL Editor."
echo "3. Verify your .env.local credentials."
echo "4. Run TypeScript checks."
echo ""
echo "Run:"
echo "  npx tsc --noEmit"
echo "  npm run build"
echo ""
echo "Then start:"
echo "  npm run dev"
echo ""
echo "========================================"
