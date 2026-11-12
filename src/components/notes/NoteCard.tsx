
import { FileText, Download, Bookmark } from "lucide-react";

interface Props {
  title: string;
  subject: string;
  semester: string;
  downloads: number;
}

export default function NoteCard({
  title,
  subject,
  semester,
  downloads,
}: Props) {
  return (
    <div className="bg-white border border-gray-100 rounded-2xl p-5 hover:shadow-md transition">
      <div className="flex justify-between items-start">
        <div className="w-11 h-11 bg-red-50 text-red-500 rounded-xl flex items-center justify-center">
          <FileText size={22} />
        </div>

        <button aria-label="Bookmark note">
          <Bookmark size={19} className="text-gray-400" />
        </button>
      </div>

      <h3 className="font-semibold mt-5">{title}</h3>

      <p className="text-sm text-gray-500 mt-2">{subject}</p>

      <div className="flex justify-between items-center mt-5 pt-4 border-t border-gray-100">
        <span className="text-xs text-gray-400">{semester}</span>
        <span className="text-xs text-gray-500 flex items-center gap-1">
          <Download size={14} /> {downloads}
        </span>
      </div>
    </div>
  );
}
