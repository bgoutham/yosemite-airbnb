import { NextResponse } from "next/server";
import { stripe } from "@/lib/stripe";
import { supabaseAdmin } from "@/lib/supabase";
import { resend } from "@/lib/resend";

export async function POST(req: Request) {
  const body = await req.text();
  const sig = req.headers.get("stripe-signature")!;

  let event;
  try {
    event = stripe.webhooks.constructEvent(
      body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET!
    );
  } catch {
    return NextResponse.json({ error: "Invalid signature" }, { status: 400 });
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object as any;
    const bookingId = session.metadata.booking_id;

    const { data: booking } = await supabaseAdmin
      .from("bookings")
      .update({
        status: "confirmed",
        stripe_payment_intent_id: session.payment_intent,
      })
      .eq("id", bookingId)
      .select()
      .single();

    if (booking) {
      const dates: { property_id: string; date: string; source: string }[] = [];
      const cur = new Date(booking.check_in);
      const end = new Date(booking.check_out);
      while (cur < end) {
        dates.push({
          property_id: booking.property_id,
          date: cur.toISOString().split("T")[0],
          source: "manual",
        });
        cur.setDate(cur.getDate() + 1);
      }
      await supabaseAdmin.from("blocked_dates").upsert(dates, {
        onConflict: "property_id,date,source",
      });

      const { data: settings } = await supabaseAdmin
        .from("site_settings")
        .select("notification_email")
        .limit(1)
        .single();

      await resend.emails.send({
        from: "Yosemite Airbnb <noreply@yosemiteairbnb.com>",
        to: booking.guest_email,
        subject: "Booking Confirmed — Yosemite Cabin",
        html: `
          <h2>Your booking is confirmed!</h2>
          <p>Hi ${booking.guest_name},</p>
          <p>Thank you for booking with us.</p>
          <ul>
            <li><strong>Check-in:</strong> ${booking.check_in}</li>
            <li><strong>Check-out:</strong> ${booking.check_out}</li>
            <li><strong>Guests:</strong> ${booking.num_guests}</li>
            <li><strong>Total:</strong> $${(booking.total_price / 100).toFixed(2)}</li>
          </ul>
          <p>We will send you detailed arrival instructions a few days before your stay.</p>
          <p>— Yosemite Airbnb</p>
        `,
      });

      if (settings?.notification_email) {
        await resend.emails.send({
          from: "Yosemite Airbnb <noreply@yosemiteairbnb.com>",
          to: settings.notification_email,
          subject: `New Booking: ${booking.guest_name} (${booking.check_in} to ${booking.check_out})`,
          html: `
            <h2>New booking received!</h2>
            <ul>
              <li><strong>Guest:</strong> ${booking.guest_name} (${booking.guest_email})</li>
              <li><strong>Dates:</strong> ${booking.check_in} to ${booking.check_out}</li>
              <li><strong>Guests:</strong> ${booking.num_guests}</li>
              <li><strong>Total:</strong> $${(booking.total_price / 100).toFixed(2)}</li>
            </ul>
          `,
        });
      }
    }
  }

  return NextResponse.json({ received: true });
}
