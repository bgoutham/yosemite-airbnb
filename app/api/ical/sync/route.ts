import { NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";
import ical from "node-ical";

export async function GET() {
  const { data: settings } = await supabaseAdmin
    .from("site_settings")
    .select("airbnb_ical_url")
    .limit(1)
    .single();

  if (!settings?.airbnb_ical_url) {
    return NextResponse.json({ error: "No iCal URL configured" }, { status: 400 });
  }

  const { data: prop } = await supabaseAdmin
    .from("property")
    .select("id")
    .limit(1)
    .single();

  if (!prop) return NextResponse.json({ error: "No property" }, { status: 500 });

  const events = await ical.async.fromURL(settings.airbnb_ical_url);

  await supabaseAdmin
    .from("blocked_dates")
    .delete()
    .eq("property_id", prop.id)
    .eq("source", "airbnb");

  const rows: any[] = [];
  for (const key in events) {
    const ev = events[key];
    if (ev.type !== "VEVENT") continue;
    const start = new Date(ev.start as Date);
    const end = new Date(ev.end as Date);
    const cur = new Date(start);
    while (cur < end) {
      rows.push({
        property_id: prop.id,
        date: cur.toISOString().split("T")[0],
        source: "airbnb",
        summary: (ev.summary as string) || "Airbnb Block",
      });
      cur.setDate(cur.getDate() + 1);
    }
  }

  if (rows.length > 0) {
    await supabaseAdmin.from("blocked_dates").upsert(rows, {
      onConflict: "property_id,date,source",
    });
  }

  return NextResponse.json({ synced: rows.length });
}
