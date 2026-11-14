
import { NextRequest, NextResponse } from "next/server";
import { createClient } from "../../../../../lib/supabase/server";

const allowedReasons = [
  "Incorrect content",
  "Copyright concern",
  "Spam",
  "Inappropriate content",
  "Other",
];

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const body = await request.json();

    if (!allowedReasons.includes(body.reason)) {
      return NextResponse.json(
        { error: "Invalid report reason." },
        { status: 400 }
      );
    }

    const supabase = await createClient();

    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json(
        { error: "Login required." },
        { status: 401 }
      );
    }

    const { error } = await supabase
      .from("reports")
      .insert({
        note_id: id,
        user_id: user.id,
        reason: body.reason,
        details:
          typeof body.details === "string"
            ? body.details.trim().slice(0, 2000)
            : null,
      });

    if (error) throw error;

    return NextResponse.json({ success: true });

  } catch (error) {
    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : "Report failed.",
      },
      { status: 400 }
    );
  }
}

