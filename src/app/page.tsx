
import Link from "next/link";
import {
  BookOpen,
  Upload,
  Search,
  ArrowRight,
  GraduationCap,
  Users,
} from "lucide-react";

const features = [
  {
    icon: Upload,
    title: "Share your notes",
    description:
      "Upload your academic notes and help other students learn.",
  },
  {
    icon: Search,
    title: "Discover resources",
    description:
      "Find study materials organized by subjects and semesters.",
  },
  {
    icon: Users,
    title: "Learn together",
    description:
      "Build a community where students help each other succeed.",
  },
];

export default function Home() {
  return (
    <main className="min-h-screen">
      <nav className="flex items-center justify-between px-6 md:px-16 py-5 bg-white border-b border-gray-100">
        <Link href="/" className="flex items-center gap-2 font-bold text-xl">
          <BookOpen className="text-indigo-600" />
          StudentNotes
        </Link>

        <div className="flex items-center gap-5">
          <Link href="/login" className="text-sm font-medium">
            Login
          </Link>
          <Link
            href="/register"
            className="bg-indigo-600 text-white px-5 py-2.5 rounded-xl text-sm"
          >
            Get Started
          </Link>
        </div>
      </nav>

      <section className="max-w-6xl mx-auto px-6 py-24 md:py-32 text-center">
        <div className="inline-flex items-center gap-2 bg-indigo-50 text-indigo-700 rounded-full px-4 py-2 text-sm mb-7">
          <GraduationCap size={17} />
          Built for students, powered by sharing
        </div>

        <h1 className="text-4xl md:text-6xl font-bold tracking-tight leading-tight">
          Your knowledge.
          <br />
          <span className="text-indigo-600">
            Shared with everyone.
          </span>
        </h1>

        <p className="max-w-2xl mx-auto text-gray-500 mt-7 text-base md:text-lg leading-relaxed">
          Discover academic notes, question papers and study
          materials shared by students. Learn together and
          make studying easier.
        </p>

        <div className="flex flex-col sm:flex-row gap-3 justify-center mt-9">
          <Link
            href="/register"
            className="bg-indigo-600 text-white rounded-xl px-7 py-3.5 font-medium flex items-center justify-center gap-2"
          >
            Start Exploring <ArrowRight size={18} />
          </Link>

          <Link
            href="/notes"
            className="border border-gray-200 bg-white rounded-xl px-7 py-3.5 font-medium"
          >
            Browse Notes
          </Link>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-5 mt-24 text-left">
          {features.map((feature) => {
            const Icon = feature.icon;

            return (
              <div
                key={feature.title}
                className="bg-white border border-gray-100 rounded-2xl p-7"
              >
                <div className="w-11 h-11 rounded-xl bg-indigo-50 text-indigo-600 flex items-center justify-center">
                  <Icon size={22} />
                </div>

                <h3 className="font-semibold text-lg mt-5">
                  {feature.title}
                </h3>

                <p className="text-gray-500 text-sm mt-2 leading-relaxed">
                  {feature.description}
                </p>
              </div>
            );
          })}
        </div>
      </section>

      <footer className="border-t border-gray-100 py-7 text-center text-sm text-gray-500">
        StudentNotes © 2026. Learn. Share. Grow.
      </footer>
    </main>
  );
}
