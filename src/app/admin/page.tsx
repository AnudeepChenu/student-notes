
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

