import { NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";
import icalGen from "ical-generator";

export async function GET() {
  const { data: bookings } = await supabaseAdmin
    .from("bookings")
    .select("*")
    .in("status", ["confirmed", "pending"]);

  const cal = icalGen({ name: "Yosemite Airbnb" });

  for (const b of bookings || []) {
    cal.createEvent({
      start: new Date(b.check_in),
      end: new Date(b.check_out),
      summary: `Booking: ${b.guest_name}`,
      description: `${b.num_guests} guests — $${(b.total_price / 100).toFixed(2)}`,
    });
  }

  return new NextResponse(cal.toString(), {
    headers: {
      "Content-Type": "text/calendar; charset=utf-8",
      "Content-Disposition": 'attachment; filename="yosemite-airbnb.ics"',
    },
  });
}
