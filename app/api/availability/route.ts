import { NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const start = searchParams.get("start");
  const end = searchParams.get("end");

  if (!start || !end) {
    return NextResponse.json([], { status: 400 });
  }

  const { data } = await supabaseAdmin.rpc("get_unavailable_dates", {
    p_start: start,
    p_end: end,
  });

  const dates = (data || []).map((r: any) => r.unavailable_date);
  return NextResponse.json(dates);
}
