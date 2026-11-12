
import DashboardLayout from "../../components/layout/DashboardLayout";
import UploadForm from "../../components/notes/UploadForm";
import { createClient } from "../../lib/supabase/server";
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

