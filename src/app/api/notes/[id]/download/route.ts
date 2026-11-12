
import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;

    const supabase = await createClient();

    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json(
        { error: "Authentication required." },
        { status: 401 }
      );
    }

    const { data: note, error } = await supabase
      .from("notes")
      .select("id, file_path, status")
      .eq("id", id)
      .maybeSingle();

    if (error || !note) {
      return NextResponse.json(
        { error: "Note not found." },
        { status: 404 }
      );
    }

    if (
      note.status !== "published" &&
      note.status !== undefined
    ) {
      return NextResponse.json(
        { error: "This note is not available." },
        { status: 403 }
      );
    }

    const { data: signed, error: signedError } =
      await supabase.storage
        .from("student-notes")
        .createSignedUrl(note.file_path, 300);

    if (signedError || !signed) {
      return NextResponse.json(
        { error: "Unable to access document." },
        { status: 500 }
      );
    }

    const { error: counterError } = await supabase.rpc(
      "increment_note_downloads",
      { p_note_id: note.id }
    );

    if (counterError) {
      console.error("Download counter error:", counterError);
    }

    return NextResponse.json({
      url: signed.signedUrl,
    });

  } catch (error) {
    console.error(error);

    return NextResponse.json(
      { error: "Unexpected server error." },
      { status: 500 }
    );
  }
}

