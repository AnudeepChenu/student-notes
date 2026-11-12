
import DashboardLayout from "../../components/layout/DashboardLayout";
import NotesExplorer from "../../components/notes/NotesExplorer";
import { createClient } from "../../lib/supabase/server";
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

