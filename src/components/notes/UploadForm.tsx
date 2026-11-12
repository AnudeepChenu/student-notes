
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

