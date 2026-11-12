
import DashboardLayout from "../../components/layout/DashboardLayout";
import {
  BookOpen,
  Download,
  Upload,
  Bookmark,
  ArrowUpRight,
} from "lucide-react";
import Link from "next/link";

const stats = [
  { label: "Notes Uploaded", value: "12", icon: Upload },
  { label: "Downloads", value: "84", icon: Download },
  { label: "Bookmarks", value: "8", icon: Bookmark },
  { label: "Available Notes", value: "240", icon: BookOpen },
];

export default function Dashboard() {
  return (
    <DashboardLayout>
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold">Dashboard</h1>
          <p className="text-gray-500 text-sm mt-1">
            Welcome back! Here's your learning overview.
          </p>
        </div>

        <Link
          href="/upload"
          className="bg-indigo-600 text-white rounded-xl px-5 py-3 text-sm font-medium flex items-center gap-2 justify-center"
        >
          <Upload size={17} />
          Upload Notes
        </Link>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-5 mt-9">
        {stats.map((stat) => {
          const Icon = stat.icon;

          return (
            <div
              key={stat.label}
              className="bg-white border border-gray-100 rounded-2xl p-5"
            >
              <div className="flex items-center justify-between">
                <p className="text-sm text-gray-500">{stat.label}</p>
                <Icon size={20} className="text-indigo-600" />
              </div>
              <h2 className="text-3xl font-bold mt-5">
                {stat.value}
              </h2>
            </div>
          );
        })}
      </div>

      <section className="mt-10 bg-white border border-gray-100 rounded-2xl p-6">
        <div className="flex justify-between items-center">
          <h2 className="font-semibold text-lg">Recently added notes</h2>
          <Link href="/notes" className="text-indigo-600 text-sm flex items-center gap-1">
            View all <ArrowUpRight size={15} />
          </Link>
        </div>

        <div className="text-center py-16">
          <BookOpen size={34} className="mx-auto text-gray-300" />
          <p className="font-medium mt-4">Your learning journey starts here</p>
          <p className="text-sm text-gray-400 mt-2">
            Notes will appear here when they are uploaded.
          </p>
        </div>
      </section>
    </DashboardLayout>
  );
}
