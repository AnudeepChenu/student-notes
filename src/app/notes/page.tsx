
import DashboardLayout from "../../components/layout/DashboardLayout";
import { Search, BookOpen } from "lucide-react";

export default function NotesPage() {
  return (
    <DashboardLayout>
      <h1 className="text-2xl font-bold">Explore Notes</h1>
      <p className="text-sm text-gray-500 mt-2">
        Discover study materials shared by students.
      </p>

      <div className="mt-8 flex items-center gap-3 bg-white border border-gray-200 rounded-xl px-4 py-3">
        <Search size={20} className="text-gray-400" />
        <input
          placeholder="Search notes, subjects or topics..."
          className="outline-none flex-1 text-sm"
        />
      </div>

      <div className="bg-white border border-gray-100 rounded-2xl mt-6 p-16 text-center">
        <BookOpen className="mx-auto text-gray-300" size={36} />
        <h2 className="font-semibold mt-4">No notes available yet</h2>
        <p className="text-sm text-gray-400 mt-2">
          Uploaded notes will appear here.
        </p>
      </div>
    </DashboardLayout>
  );
}
