
import { NextRequest, NextResponse } from "next/server";
import { createClient } from "../../../../../lib/supabase/server";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const body = await request.json();

    const rating = Number(body.rating);
    const comment = typeof body.comment === "string"
      ? body.comment.trim().slice(0, 2000)
      : null;

    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      return NextResponse.json(
        { error: "Rating must be between 1 and 5." },
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
      .from("reviews")
      .upsert(
        {
          note_id: id,
          user_id: user.id,
          rating,
          comment,
        },
        { onConflict: "user_id,note_id" }
      );

    if (error) throw error;

    return NextResponse.json({ success: true });

  } catch (error) {
    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : "Review failed.",
      },
      { status: 400 }
    );
  }
}

