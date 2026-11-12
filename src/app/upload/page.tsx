
import DashboardLayout from "../../components/layout/DashboardLayout";
import { Upload } from "lucide-react";

export default function UploadPage() {
  return (
    <DashboardLayout>
      <h1 className="text-2xl font-bold">Upload Notes</h1>
      <p className="text-gray-500 text-sm mt-2">
        Share your knowledge with other students.
      </p>

      <div className="bg-white border border-gray-200 rounded-2xl p-8 mt-8 max-w-2xl">
        <div className="border-2 border-dashed border-gray-200 rounded-xl p-12 text-center">
          <Upload className="mx-auto text-indigo-600" size={32} />
          <h2 className="font-semibold mt-4">
            Upload your PDF
          </h2>
          <p className="text-sm text-gray-400 mt-2">
            PDF documents will be supported.
          </p>
          <p className="text-xs text-gray-400 mt-1">
            Upload functionality coming in Sprint 3.
          </p>
        </div>
      </div>
    </DashboardLayout>
  );
}
