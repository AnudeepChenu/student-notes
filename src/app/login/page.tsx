
"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { BookOpen } from "lucide-react";
import { createClient } from "../../lib/supabase/client";

export default function LoginPage() {
  const router = useRouter();
  const supabase = createClient();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      setError(error.message);
      setLoading(false);
      return;
    }

    router.replace("/dashboard");
    router.refresh();
  }

  async function handleGoogleLogin() {
    setError("");

    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    });

    if (error) setError(error.message);
  }

  return (
    <main className="min-h-screen flex items-center justify-center p-5">
      <div className="bg-white border border-gray-100 rounded-2xl p-8 w-full max-w-md">
        <Link href="/" className="flex items-center gap-2 font-bold text-xl">
          <BookOpen className="text-indigo-600" />
          StudentNotes
        </Link>

        <h1 className="text-2xl font-bold mt-9">Welcome back</h1>
        <p className="text-gray-500 text-sm mt-2">
          Login to your StudentNotes account.
        </p>

        <form onSubmit={handleLogin} className="space-y-5 mt-8">
          <div>
            <label className="text-sm font-medium">Email</label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@example.com"
              className="w-full border border-gray-200 rounded-xl p-3 mt-2 text-sm"
            />
          </div>

          <div>
            <label className="text-sm font-medium">Password</label>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Enter password"
              className="w-full border border-gray-200 rounded-xl p-3 mt-2 text-sm"
            />
          </div>

          {error && (
            <p role="alert" className="text-sm text-red-600">{error}</p>
          )}

          <button
            disabled={loading}
            className="w-full bg-indigo-600 text-white rounded-xl py-3 font-medium disabled:opacity-60"
          >
            {loading ? "Logging in..." : "Login"}
          </button>
        </form>

        <div className="flex items-center gap-3 my-6">
          <div className="h-px bg-gray-200 flex-1" />
          <span className="text-xs text-gray-400">OR</span>
          <div className="h-px bg-gray-200 flex-1" />
        </div>

        <button
          onClick={handleGoogleLogin}
          className="w-full border border-gray-200 rounded-xl py-3 text-sm font-medium"
        >
          Continue with Google
        </button>

        <p className="text-sm text-center text-gray-500 mt-6">
          Don't have an account?{" "}
          <Link href="/register" className="text-indigo-600 font-medium">
            Register
          </Link>
        </p>
      </div>
    </main>
  );
}
