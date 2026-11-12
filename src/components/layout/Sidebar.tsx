"use client";

import { useRouter, usePathname } from "next/navigation";
import { createClient } from "../../lib/supabase/client";
import Link from "next/link";

import {
  LayoutDashboard,
  BookOpen,
  Upload,
  Bookmark,
  User,
  GraduationCap,
  LogOut,
} from "lucide-react";

const links = [
  { name: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  { name: "Explore Notes", href: "/notes", icon: BookOpen },
  { name: "Upload Notes", href: "/upload", icon: Upload },
  { name: "Bookmarks", href: "/bookmarks", icon: Bookmark },
  { name: "My Profile", href: "/profile", icon: User },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();

  async function handleLogout() {
    const supabase = createClient();

    await supabase.auth.signOut();

    router.replace("/login");
    router.refresh();
  }

  return (
    <aside className="w-64 min-h-screen bg-white border-r border-gray-100 p-5 hidden md:flex flex-col">
      <Link
        href="/"
        className="flex items-center gap-2 font-bold text-xl mb-12"
      >
        <GraduationCap className="text-indigo-600" />
        StudentNotes
      </Link>

      <p className="text-xs text-gray-400 font-semibold mb-4 px-3">
        MENU
      </p>

      <nav className="space-y-2">
        {links.map((link) => {
          const Icon = link.icon;
          const active = pathname === link.href;

          return (
            <Link
              key={link.href}
              href={link.href}
              className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition ${
                active
                  ? "bg-indigo-50 text-indigo-700"
                  : "text-gray-500 hover:bg-gray-50"
              }`}
            >
              <Icon size={19} />
              {link.name}
            </Link>
          );
        })}
      </nav>

      <div className="mt-auto space-y-4">
        <div className="bg-indigo-50 rounded-xl p-4">
          <p className="text-sm font-semibold text-indigo-800">
            Learn together.
          </p>
          <p className="text-xs text-indigo-600 mt-1">
            Share knowledge and grow together.
          </p>
        </div>

        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-red-500 hover:bg-red-50 transition"
        >
          <LogOut size={19} />
          Logout
        </button>
      </div>
    </aside>
  );
}