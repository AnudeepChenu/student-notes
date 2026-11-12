
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

