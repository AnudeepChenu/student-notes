
import Link from "next/link";
import Input from "../../components/ui/Input";
import Button from "../../components/ui/Button";

export default function LoginPage() {
  return (
    <main className="min-h-screen flex items-center justify-center p-5">
      <div className="bg-white border border-gray-100 rounded-2xl p-8 w-full max-w-md">
        <h1 className="text-2xl font-bold">Welcome back</h1>
        <p className="text-gray-500 text-sm mt-2">
          Login to your StudentNotes account.
        </p>

        <div className="space-y-5 mt-8">
          <Input label="Email" type="email" placeholder="you@example.com" />
          <Input label="Password" type="password" placeholder="Enter password" />
          <Button className="w-full">Login</Button>
        </div>

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
