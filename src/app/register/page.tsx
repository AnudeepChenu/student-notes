
import Link from "next/link";
import Input from "../../components/ui/Input";
import Button from "../../components/ui/Button";

export default function RegisterPage() {
  return (
    <main className="min-h-screen flex items-center justify-center p-5">
      <div className="bg-white border border-gray-100 rounded-2xl p-8 w-full max-w-md">
        <h1 className="text-2xl font-bold">Create your account</h1>
        <p className="text-gray-500 text-sm mt-2">
          Join the StudentNotes community.
        </p>

        <div className="space-y-5 mt-8">
          <Input label="Full name" placeholder="Your name" />
          <Input label="Email" type="email" placeholder="you@example.com" />
          <Input label="Password" type="password" placeholder="Create password" />
          <Button className="w-full">Create Account</Button>
        </div>

        <p className="text-sm text-center text-gray-500 mt-6">
          Already registered?{" "}
          <Link href="/login" className="text-indigo-600 font-medium">
            Login
          </Link>
        </p>
      </div>
    </main>
  );
}
