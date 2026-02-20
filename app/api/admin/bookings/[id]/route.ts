import { NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";

export async function DELETE(
  _req: Request,
  { params }: { params: { id: string } }
) {
  const { id } = params;

  const { data: booking } = await supabaseAdmin
    .from("bookings")
    .select("*")
    .eq("id", id)
    .single();

  if (!booking) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }

  await supabaseAdmin
    .from("bookings")
    .update({ status: "cancelled" })
    .eq("id", id);

  const dates: string[] = [];
  const cur = new Date(booking.check_in);
  const end = new Date(booking.check_out);
  while (cur < end) {
    dates.push(cur.toISOString().split("T")[0]);
    cur.setDate(cur.getDate() + 1);
  }

  await supabaseAdmin
    .from("blocked_dates")
    .delete()
    .eq("property_id", booking.property_id)
    .eq("source", "manual")
    .in("date", dates);

  return NextResponse.json({ cancelled: true });
}
