
"use client";

import { Bell, Search } from "lucide-react";

export default function Header() {
  return (
    <header className="flex items-center justify-between gap-4 mb-8">
      <div className="relative w-full max-w-md">
        <Search
          size={18}
          className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400"
        />
        <input
          placeholder="Search resources..."
          className="w-full bg-white border border-gray-200 rounded-xl py-3 pl-11 pr-4 text-sm outline-none"
        />
      </div>

      <button
        aria-label="Notifications"
        className="w-11 h-11 bg-white border border-gray-200 rounded-xl flex items-center justify-center"
      >
        <Bell size={19} className="text-gray-500" />
      </button>
    </header>
  );
}
