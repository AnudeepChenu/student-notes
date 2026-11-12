
export interface Student {
  id: string;
  name: string;
  email: string;
  college: string;
  department: string;
  semester: number;
}

export interface Note {
  id: string;
  title: string;
  description: string;
  subject: string;
  semester: number;
  fileUrl: string;
  uploadedBy: string;
  downloads: number;
  createdAt: string;
}
