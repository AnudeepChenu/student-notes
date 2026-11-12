
import Sidebar from "./Sidebar";
import Header from "./Header";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen">
      <Sidebar />

      <main className="flex-1 min-w-0 p-5 md:p-10">
        <Header />
        {children}
      </main>
    </div>
  );
}
