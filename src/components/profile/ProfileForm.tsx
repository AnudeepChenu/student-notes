
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

