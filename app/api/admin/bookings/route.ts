import { NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";

export async function GET() {
  const { data } = await supabaseAdmin
    .from("bookings")
    .select("*")
    .order("check_in", { ascending: false });

  return NextResponse.json(data || []);
}
