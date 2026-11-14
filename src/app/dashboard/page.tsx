import DashboardLayout from "../../components/layout/DashboardLayout";
import { createClient } from "../../lib/supabase/server";
import { redirect } from "next/navigation";
import Link from "next/link";

import {
  BookOpen,
  Download,
  Bookmark,
  Upload,
  ArrowRight,
} from "lucide-react";


export const instant = false;

export default async function Dashboard() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

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
    {
      label: "My Uploads",
      value: uploads || 0,
      icon: Upload,
    },
    {
      label: "Downloads of my notes",
      value: totalDownloads,
      icon: Download,
    },
    {
      label: "Bookmarks",
      value: bookmarks || 0,
      icon: Bookmark,
    },
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
          className="bg-indigo-600 text-white rounded-xl px-5 py-3 text-sm flex items-center justify-center gap-2 hover:bg-indigo-700 transition"
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
          <h2 className="font-semibold text-lg">
            Recently uploaded notes
          </h2>

          <Link
            href="/notes"
            className="text-indigo-600 text-sm flex items-center gap-2"
          >
            Explore <ArrowRight size={15} />
          </Link>
        </div>

        {!recent?.length ? (
          <div className="text-center py-12">
            <BookOpen
              className="mx-auto text-gray-300"
              size={35}
            />

            <p className="font-medium mt-4">
              No notes available yet
            </p>
          </div>
        ) : (
          <div className="divide-y">
            {recent.map((note) => (
              <div
                key={note.id}
                className="py-4 flex justify-between items-center gap-3"
              >
                <div>
                  <p className="font-medium text-sm">
                    {note.title}
                  </p>

                  <p className="text-xs text-gray-400 mt-1">
                    {note.subject} · Semester {note.semester}
                  </p>
                </div>

                <BookOpen
                  size={19}
                  className="text-indigo-500"
                />
              </div>
            ))}
          </div>
        )}
      </section>
    </DashboardLayout>
  );
}