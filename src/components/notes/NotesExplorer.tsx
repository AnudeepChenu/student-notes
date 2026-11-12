
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

