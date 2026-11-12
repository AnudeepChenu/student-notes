
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

