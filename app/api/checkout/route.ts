import { NextResponse } from "next/server";
import { stripe } from "@/lib/stripe";
import { supabaseAdmin } from "@/lib/supabase";
import { calculatePricing } from "@/lib/pricing";

export async function POST(req: Request) {
  const body = await req.json();
  const { checkIn, checkOut, guests, name, email, phone } = body;

  const { data: prop } = await supabaseAdmin
    .from("property")
    .select("*")
    .limit(1)
    .single();

  if (!prop) return NextResponse.json({ error: "No property" }, { status: 500 });

  const { data: available } = await supabaseAdmin.rpc("check_availability", {
    p_check_in: checkIn,
    p_check_out: checkOut,
  });

  if (!available) {
    return NextResponse.json(
      { error: "Dates are not available" },
      { status: 409 }
    );
  }

  const nights = Math.round(
    (new Date(checkOut).getTime() - new Date(checkIn).getTime()) / 86400000
  );
  const pricing = calculatePricing(
    prop.base_price,
    nights,
    prop.cleaning_fee,
    Number(prop.service_fee_pct)
  );

  const { data: booking } = await supabaseAdmin
    .from("bookings")
    .insert({
      property_id: prop.id,
      guest_name: name,
      guest_email: email,
      guest_phone: phone || null,
      check_in: checkIn,
      check_out: checkOut,
      num_guests: guests,
      num_nights: nights,
      nightly_rate: prop.base_price,
      cleaning_fee: prop.cleaning_fee,
      service_fee: pricing.serviceFee,
      total_price: pricing.total,
      status: "pending",
      source: "direct",
    })
    .select()
    .single();

  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    customer_email: email,
    line_items: [
      {
        price_data: {
          currency: "usd",
          product_data: {
            name: `${prop.name} — ${nights} night${nights > 1 ? "s" : ""}`,
            description: `${checkIn} to ${checkOut} · ${guests} guest${guests > 1 ? "s" : ""}`,
          },
          unit_amount: pricing.total,
        },
        quantity: 1,
      },
    ],
    metadata: {
      booking_id: booking!.id,
    },
    success_url: `${process.env.NEXT_PUBLIC_BASE_URL}/booking/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.NEXT_PUBLIC_BASE_URL}/booking`,
  });

  await supabaseAdmin
    .from("bookings")
    .update({ stripe_session_id: session.id })
    .eq("id", booking!.id);

  return NextResponse.json({ url: session.url });
}
