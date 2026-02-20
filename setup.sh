#!/bin/bash
# Run from your project root: bash setup.sh

# ── Create directories ──
mkdir -p lib
mkdir -p app/booking/success
mkdir -p app/admin
mkdir -p app/api/availability
mkdir -p app/api/checkout
mkdir -p app/api/webhook
mkdir -p app/api/ical/sync
mkdir -p app/api/ical/export
mkdir -p app/api/admin/auth
mkdir -p "app/api/admin/bookings/[id]"
mkdir -p public

# ── .env.local.example ──
cat > .env.local.example << 'EOF'
# ── Supabase ──────────────────────────────────────────
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# ── Stripe ────────────────────────────────────────────
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...

# ── Resend ────────────────────────────────────────────
RESEND_API_KEY=re_...

# ── App ───────────────────────────────────────────────
NEXT_PUBLIC_BASE_URL=http://localhost:3000
ADMIN_PASSWORD=choose-a-strong-password
EOF

# ── lib/supabase.ts ──
cat > lib/supabase.ts << 'EOF'
import { createClient } from "@supabase/supabase-js";

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

export const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);
EOF

# ── lib/stripe.ts ──
cat > lib/stripe.ts << 'EOF'
import Stripe from "stripe";

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2024-12-18.acacia",
});
EOF

# ── lib/resend.ts ──
cat > lib/resend.ts << 'EOF'
import { Resend } from "resend";

export const resend = new Resend(process.env.RESEND_API_KEY);
EOF

# ── lib/pricing.ts ──
cat > lib/pricing.ts << 'EOF'
export function calculatePricing(
  nightlyRate: number,
  numNights: number,
  cleaningFee: number,
  serviceFeePct: number
) {
  const subtotal = nightlyRate * numNights;
  const serviceFee = Math.round(subtotal * serviceFeePct);
  const total = subtotal + cleaningFee + serviceFee;
  return { subtotal, cleaningFee, serviceFee, total, numNights };
}

export function centsToStr(c: number) {
  return (c / 100).toFixed(2);
}

export function centsToDollars(c: number) {
  return `$${(c / 100).toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`;
}
EOF

# ── app/globals.css ──
cat > app/globals.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --forest: #2d5016;
  --forest-light: #4a7c28;
  --bark: #8b6914;
  --cream: #faf8f0;
  --stone: #6b7280;
  --charcoal: #1f2937;
}

body {
  font-family: "Inter", system-ui, sans-serif;
  color: var(--charcoal);
  background: var(--cream);
}

.hero-bg {
  background: linear-gradient(
      135deg,
      rgba(0, 0, 0, 0.55) 0%,
      rgba(0, 0, 0, 0.2) 100%
    ),
    url("/hero.jpg") center/cover no-repeat;
  min-height: 100vh;
}

.glass {
  background: rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(16px);
  border: 1px solid rgba(255, 255, 255, 0.18);
}

.btn-primary {
  @apply px-6 py-3 rounded-lg font-semibold text-white transition-all;
  background: var(--forest);
}
.btn-primary:hover {
  background: var(--forest-light);
  transform: translateY(-1px);
  box-shadow: 0 4px 14px rgba(45, 80, 22, 0.35);
}

.card {
  @apply rounded-2xl bg-white shadow-lg p-6;
}

.input {
  @apply w-full px-4 py-3 rounded-lg border border-gray-300 focus:border-green-600 focus:ring-2 focus:ring-green-200 outline-none transition-all;
}

.calendar-day {
  @apply w-10 h-10 flex items-center justify-center rounded-full text-sm cursor-pointer transition-all;
}
.calendar-day:hover:not(.unavailable):not(.selected) {
  @apply bg-green-100;
}
.calendar-day.selected {
  background: var(--forest);
  @apply text-white;
}
.calendar-day.in-range {
  @apply bg-green-100;
}
.calendar-day.unavailable {
  @apply text-gray-300 cursor-not-allowed line-through;
}

.fade-in {
  animation: fadeIn 0.6s ease-out;
}
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(12px); }
  to   { opacity: 1; transform: translateY(0); }
}
EOF

# ── app/layout.tsx ──
cat > app/layout.tsx << 'EOF'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Yosemite Airbnb — Stay in Nature's Paradise",
  description:
    "Book a beautiful cabin near Yosemite National Park. Mountain views, hot tub, hiking trails from your doorstep.",
  openGraph: {
    title: "Yosemite Airbnb",
    description: "Your dream cabin near Yosemite National Park",
    type: "website",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
EOF

# ── app/page.tsx ──
cat > app/page.tsx << 'PAGEEOF'
"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import Link from "next/link";

const AMENITY_ICONS: Record<string, string> = {
  WiFi: "📶",
  "Full Kitchen": "🍳",
  Fireplace: "🔥",
  "Hot Tub": "♨️",
  "BBQ Grill": "🥩",
  "Free Parking": "🅿️",
  "Washer / Dryer": "👕",
  "Mountain Views": "🏔️",
  "Hiking Trails": "🥾",
  "Pet Friendly": "🐕",
};

export default function Home() {
  const [property, setProperty] = useState<any>(null);

  useEffect(() => {
    supabase
      .from("property")
      .select("*")
      .limit(1)
      .single()
      .then(({ data }) => setProperty(data));
  }, []);

  if (!property) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[var(--cream)]">
        <div className="animate-pulse text-[var(--forest)] text-xl">Loading...</div>
      </div>
    );
  }

  return (
    <main>
      <section className="hero-bg flex items-center justify-center text-white text-center px-4">
        <div className="max-w-3xl fade-in">
          <h1 className="text-5xl md:text-7xl font-bold mb-4 tracking-tight">
            {property.name}
          </h1>
          <p className="text-xl md:text-2xl mb-2 opacity-90">{property.tagline}</p>
          <p className="text-lg opacity-70 mb-8">
            {property.bedrooms} bed · {property.bathrooms} bath · Up to{" "}
            {property.max_guests} guests
          </p>
          <Link href="/booking" className="btn-primary text-lg px-8 py-4 inline-block">
            Check Availability & Book
          </Link>
        </div>
      </section>

      <section className="max-w-4xl mx-auto py-20 px-6 fade-in">
        <h2 className="text-3xl font-bold mb-6 text-[var(--forest)]">
          About the Property
        </h2>
        <p className="text-lg leading-relaxed text-gray-700">{property.description}</p>
        <div className="mt-8 flex flex-wrap gap-4 text-sm">
          <span className="bg-green-50 text-[var(--forest)] px-4 py-2 rounded-full font-medium">
            📍 Near Yosemite National Park
          </span>
          <span className="bg-green-50 text-[var(--forest)] px-4 py-2 rounded-full font-medium">
            🕐 Check-in {property.check_in_time}
          </span>
          <span className="bg-green-50 text-[var(--forest)] px-4 py-2 rounded-full font-medium">
            🕐 Check-out {property.check_out_time}
          </span>
          <span className="bg-green-50 text-[var(--forest)] px-4 py-2 rounded-full font-medium">
            🌙 {property.min_nights}-night minimum
          </span>
        </div>
      </section>

      <section className="bg-white py-20 px-6">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-3xl font-bold mb-8 text-[var(--forest)]">Amenities</h2>
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
            {(property.amenities || []).map((a: string) => (
              <div
                key={a}
                className="flex flex-col items-center gap-2 p-4 rounded-xl bg-[var(--cream)] hover:shadow-md transition-shadow"
              >
                <span className="text-2xl">{AMENITY_ICONS[a] || "✨"}</span>
                <span className="text-sm font-medium text-center">{a}</span>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="max-w-4xl mx-auto py-20 px-6 text-center">
        <h2 className="text-3xl font-bold mb-4 text-[var(--forest)]">Pricing</h2>
        <div className="text-5xl font-bold text-[var(--charcoal)] mb-2">
          ${(property.base_price / 100).toFixed(0)}
          <span className="text-xl font-normal text-gray-500"> / night</span>
        </div>
        <p className="text-gray-500 mb-8">
          + ${(property.cleaning_fee / 100).toFixed(0)} cleaning fee · {(Number(property.service_fee_pct) * 100).toFixed(0)}% service fee
        </p>
        <Link href="/booking" className="btn-primary text-lg px-8 py-4 inline-block">
          Book Your Stay
        </Link>
      </section>

      <footer className="bg-[var(--charcoal)] text-gray-400 py-10 px-6 text-center">
        <p className="text-white font-semibold text-lg mb-2">{property.name}</p>
        <p className="text-sm">© {new Date().getFullYear()} Yosemite Airbnb. All rights reserved.</p>
      </footer>
    </main>
  );
}
PAGEEOF

# ── app/booking/page.tsx ──
cat > app/booking/page.tsx << 'BOOKEOF'
"use client";

import { useEffect, useState, useMemo } from "react";
import { supabase } from "@/lib/supabase";
import { calculatePricing, centsToDollars } from "@/lib/pricing";
import Link from "next/link";

function daysInMonth(y: number, m: number) {
  return new Date(y, m + 1, 0).getDate();
}
function dateStr(d: Date) {
  return d.toISOString().split("T")[0];
}
function addDays(d: Date, n: number) {
  const r = new Date(d);
  r.setDate(r.getDate() + n);
  return r;
}

export default function BookingPage() {
  const [property, setProperty] = useState<any>(null);
  const [unavailable, setUnavailable] = useState<Set<string>>(new Set());
  const [checkIn, setCheckIn] = useState<Date | null>(null);
  const [checkOut, setCheckOut] = useState<Date | null>(null);
  const [guests, setGuests] = useState(1);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [loading, setLoading] = useState(false);
  const [month, setMonth] = useState(new Date().getMonth());
  const [year, setYear] = useState(new Date().getFullYear());

  useEffect(() => {
    supabase.from("property").select("*").limit(1).single()
      .then(({ data }) => setProperty(data));
  }, []);

  useEffect(() => {
    const start = new Date(year, month, 1);
    const end = new Date(year, month + 2, 0);
    fetch(`/api/availability?start=${dateStr(start)}&end=${dateStr(end)}`)
      .then((r) => r.json())
      .then((dates: string[]) => setUnavailable(new Set(dates)));
  }, [month, year]);

  const pricing = useMemo(() => {
    if (!checkIn || !checkOut || !property) return null;
    const nights = Math.round(
      (checkOut.getTime() - checkIn.getTime()) / 86400000
    );
    if (nights < (property.min_nights || 1)) return null;
    return calculatePricing(
      property.base_price,
      nights,
      property.cleaning_fee,
      Number(property.service_fee_pct)
    );
  }, [checkIn, checkOut, property]);

  function handleDayClick(d: Date) {
    const s = dateStr(d);
    if (unavailable.has(s)) return;
    if (!checkIn || (checkIn && checkOut)) {
      setCheckIn(d);
      setCheckOut(null);
    } else {
      if (d <= checkIn) {
        setCheckIn(d);
        setCheckOut(null);
      } else {
        let cur = new Date(checkIn);
        while (cur < d) {
          if (unavailable.has(dateStr(cur))) {
            setCheckIn(d);
            setCheckOut(null);
            return;
          }
          cur = addDays(cur, 1);
        }
        setCheckOut(d);
      }
    }
  }

  function dayClass(d: Date) {
    const s = dateStr(d);
    const today = dateStr(new Date());
    if (s < today) return "calendar-day unavailable";
    if (unavailable.has(s)) return "calendar-day unavailable";
    if (checkIn && dateStr(checkIn) === s) return "calendar-day selected";
    if (checkOut && dateStr(checkOut) === s) return "calendar-day selected";
    if (checkIn && checkOut && d > checkIn && d < checkOut) return "calendar-day in-range";
    return "calendar-day";
  }

  async function handleBook() {
    if (!pricing || !name || !email) return;
    setLoading(true);
    try {
      const res = await fetch("/api/checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          checkIn: dateStr(checkIn!),
          checkOut: dateStr(checkOut!),
          guests,
          name,
          email,
          phone,
        }),
      });
      const { url } = await res.json();
      if (url) window.location.href = url;
    } catch {
      alert("Something went wrong. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  function renderMonth(y: number, m: number) {
    const first = new Date(y, m, 1).getDay();
    const total = daysInMonth(y, m);
    const label = new Date(y, m).toLocaleString("default", {
      month: "long",
      year: "numeric",
    });
    const blanks = Array.from({ length: first }, (_, i) => (
      <div key={`b${i}`} className="w-10 h-10" />
    ));
    const days = Array.from({ length: total }, (_, i) => {
      const d = new Date(y, m, i + 1);
      return (
        <div key={i} className={dayClass(d)} onClick={() => handleDayClick(d)}>
          {i + 1}
        </div>
      );
    });
    return (
      <div>
        <h3 className="font-semibold text-center mb-3">{label}</h3>
        <div className="grid grid-cols-7 gap-1 text-center text-xs text-gray-500 mb-2">
          {["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"].map((d) => (
            <div key={d}>{d}</div>
          ))}
        </div>
        <div className="grid grid-cols-7 gap-1">{blanks}{days}</div>
      </div>
    );
  }

  function prevMonth() {
    if (month === 0) { setMonth(11); setYear(year - 1); }
    else setMonth(month - 1);
  }
  function nextMonth() {
    if (month === 11) { setMonth(0); setYear(year + 1); }
    else setMonth(month + 1);
  }

  if (!property) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[var(--cream)]">
        <div className="animate-pulse text-[var(--forest)] text-xl">Loading...</div>
      </div>
    );
  }

  return (
    <main className="min-h-screen bg-[var(--cream)]">
      <nav className="bg-white shadow-sm px-6 py-4">
        <div className="max-w-6xl mx-auto flex items-center justify-between">
          <Link href="/" className="text-xl font-bold text-[var(--forest)]">
            {property.name}
          </Link>
        </div>
      </nav>

      <div className="max-w-6xl mx-auto px-6 py-10 grid md:grid-cols-3 gap-8">
        <div className="md:col-span-2 card fade-in">
          <h2 className="text-2xl font-bold mb-6 text-[var(--forest)]">
            Select Your Dates
          </h2>
          <div className="flex items-center justify-between mb-6">
            <button onClick={prevMonth} className="p-2 hover:bg-gray-100 rounded-lg">
              ← Prev
            </button>
            <button onClick={nextMonth} className="p-2 hover:bg-gray-100 rounded-lg">
              Next →
            </button>
          </div>
          <div className="grid md:grid-cols-2 gap-8">
            {renderMonth(year, month)}
            {renderMonth(
              month === 11 ? year + 1 : year,
              month === 11 ? 0 : month + 1
            )}
          </div>
          {checkIn && (
            <p className="mt-4 text-sm text-gray-600">
              Check-in: <strong>{checkIn.toLocaleDateString()}</strong>
              {checkOut && (
                <> · Check-out: <strong>{checkOut.toLocaleDateString()}</strong></>
              )}
            </p>
          )}
        </div>

        <div className="card h-fit sticky top-6 fade-in">
          <h3 className="text-lg font-bold mb-1">{centsToDollars(property.base_price)} / night</h3>
          <p className="text-sm text-gray-500 mb-6">{property.min_nights}-night minimum</p>

          <label className="block text-sm font-medium mb-1">Name</label>
          <input className="input mb-3" value={name} onChange={(e) => setName(e.target.value)} />

          <label className="block text-sm font-medium mb-1">Email</label>
          <input className="input mb-3" type="email" value={email} onChange={(e) => setEmail(e.target.value)} />

          <label className="block text-sm font-medium mb-1">Phone (optional)</label>
          <input className="input mb-3" type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} />

          <label className="block text-sm font-medium mb-1">Guests</label>
          <select
            className="input mb-6"
            value={guests}
            onChange={(e) => setGuests(Number(e.target.value))}
          >
            {Array.from({ length: property.max_guests }, (_, i) => (
              <option key={i + 1} value={i + 1}>{i + 1} guest{i > 0 ? "s" : ""}</option>
            ))}
          </select>

          {pricing && (
            <div className="border-t pt-4 mb-4 space-y-2 text-sm">
              <div className="flex justify-between">
                <span>{centsToDollars(property.base_price)} × {pricing.numNights} nights</span>
                <span>{centsToDollars(pricing.subtotal)}</span>
              </div>
              <div className="flex justify-between">
                <span>Cleaning fee</span>
                <span>{centsToDollars(pricing.cleaningFee)}</span>
              </div>
              <div className="flex justify-between">
                <span>Service fee</span>
                <span>{centsToDollars(pricing.serviceFee)}</span>
              </div>
              <div className="flex justify-between font-bold text-base border-t pt-2">
                <span>Total</span>
                <span>{centsToDollars(pricing.total)}</span>
              </div>
            </div>
          )}

          <button
            onClick={handleBook}
            disabled={!pricing || !name || !email || loading}
            className="btn-primary w-full text-center disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? "Redirecting to payment..." : "Book & Pay"}
          </button>
        </div>
      </div>
    </main>
  );
}
BOOKEOF

# ── app/booking/success/page.tsx ──
cat > app/booking/success/page.tsx << 'EOF'
import Link from "next/link";

export default function BookingSuccess() {
  return (
    <main className="min-h-screen bg-[var(--cream)] flex items-center justify-center px-6">
      <div className="card max-w-lg text-center fade-in">
        <div className="text-5xl mb-4">🎉</div>
        <h1 className="text-3xl font-bold text-[var(--forest)] mb-3">
          Booking Confirmed!
        </h1>
        <p className="text-gray-600 mb-6">
          Thank you for your reservation. You will receive a confirmation email
          shortly with all the details for your stay.
        </p>
        <Link href="/" className="btn-primary inline-block">
          Back to Home
        </Link>
      </div>
    </main>
  );
}
EOF

# ── app/api/availability/route.ts ──
cat > app/api/availability/route.ts << 'EOF'
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
EOF

# ── app/api/checkout/route.ts ──
cat > app/api/checkout/route.ts << 'EOF'
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
EOF

# ── app/api/webhook/route.ts ──
cat > app/api/webhook/route.ts << 'EOF'
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
EOF

# ── app/api/ical/sync/route.ts ──
cat > app/api/ical/sync/route.ts << 'EOF'
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
EOF

# ── app/api/ical/export/route.ts ──
cat > app/api/ical/export/route.ts << 'EOF'
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
EOF

# ── app/admin/page.tsx ──
cat > app/admin/page.tsx << 'ADMINEOF'
"use client";

import { useEffect, useState } from "react";
import { centsToDollars } from "@/lib/pricing";

export default function AdminPage() {
  const [pw, setPw] = useState("");
  const [authed, setAuthed] = useState(false);
  const [bookings, setBookings] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [syncMsg, setSyncMsg] = useState("");

  async function login() {
    const res = await fetch("/api/admin/auth", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ password: pw }),
    });
    if (res.ok) {
      setAuthed(true);
      loadBookings();
    } else {
      alert("Wrong password");
    }
  }

  async function loadBookings() {
    const res = await fetch("/api/admin/bookings");
    const data = await res.json();
    setBookings(data);
  }

  async function syncAirbnb() {
    setLoading(true);
    setSyncMsg("");
    const res = await fetch("/api/ical/sync");
    const data = await res.json();
    setSyncMsg(`Synced ${data.synced} blocked dates from Airbnb`);
    setLoading(false);
  }

  async function cancelBooking(id: string) {
    if (!confirm("Cancel this booking?")) return;
    await fetch(`/api/admin/bookings/${id}`, { method: "DELETE" });
    loadBookings();
  }

  if (!authed) {
    return (
      <main className="min-h-screen bg-[var(--cream)] flex items-center justify-center px-6">
        <div className="card max-w-sm w-full">
          <h1 className="text-2xl font-bold text-[var(--forest)] mb-4">Admin Login</h1>
          <input
            type="password"
            className="input mb-4"
            placeholder="Admin password"
            value={pw}
            onChange={(e) => setPw(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && login()}
          />
          <button onClick={login} className="btn-primary w-full text-center">
            Login
          </button>
        </div>
      </main>
    );
  }

  const statusColor: Record<string, string> = {
    confirmed: "bg-green-100 text-green-800",
    pending: "bg-yellow-100 text-yellow-800",
    cancelled: "bg-red-100 text-red-800",
    completed: "bg-gray-100 text-gray-800",
  };

  return (
    <main className="min-h-screen bg-[var(--cream)]">
      <nav className="bg-white shadow-sm px-6 py-4">
        <div className="max-w-6xl mx-auto flex items-center justify-between">
          <h1 className="text-xl font-bold text-[var(--forest)]">Admin Dashboard</h1>
          <button
            onClick={syncAirbnb}
            disabled={loading}
            className="btn-primary text-sm px-4 py-2"
          >
            {loading ? "Syncing..." : "Sync Airbnb Calendar"}
          </button>
        </div>
      </nav>

      <div className="max-w-6xl mx-auto px-6 py-8">
        {syncMsg && (
          <div className="bg-green-50 text-green-800 px-4 py-3 rounded-lg mb-6">
            {syncMsg}
          </div>
        )}

        <div className="card">
          <h2 className="text-xl font-bold mb-4">Bookings</h2>
          {bookings.length === 0 ? (
            <p className="text-gray-500">No bookings yet.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b text-left">
                    <th className="pb-3 font-semibold">Guest</th>
                    <th className="pb-3 font-semibold">Dates</th>
                    <th className="pb-3 font-semibold">Guests</th>
                    <th className="pb-3 font-semibold">Total</th>
                    <th className="pb-3 font-semibold">Source</th>
                    <th className="pb-3 font-semibold">Status</th>
                    <th className="pb-3 font-semibold">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {bookings.map((b) => (
                    <tr key={b.id} className="border-b last:border-0">
                      <td className="py-3">
                        <div className="font-medium">{b.guest_name}</div>
                        <div className="text-gray-500 text-xs">{b.guest_email}</div>
                      </td>
                      <td className="py-3">{b.check_in} → {b.check_out}</td>
                      <td className="py-3">{b.num_guests}</td>
                      <td className="py-3">{centsToDollars(b.total_price)}</td>
                      <td className="py-3 capitalize">{b.source}</td>
                      <td className="py-3">
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${statusColor[b.status] || ""}`}>
                          {b.status}
                        </span>
                      </td>
                      <td className="py-3">
                        {b.status !== "cancelled" && (
                          <button
                            onClick={() => cancelBooking(b.id)}
                            className="text-red-600 hover:underline text-xs"
                          >
                            Cancel
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </main>
  );
}
ADMINEOF

# ── app/api/admin/auth/route.ts ──
cat > app/api/admin/auth/route.ts << 'EOF'
import { NextResponse } from "next/server";

export async function POST(req: Request) {
  const { password } = await req.json();
  if (password === process.env.ADMIN_PASSWORD) {
    return NextResponse.json({ ok: true });
  }
  return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
}
EOF

# ── app/api/admin/bookings/route.ts ──
cat > app/api/admin/bookings/route.ts << 'EOF'
import { NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";

export async function GET() {
  const { data } = await supabaseAdmin
    .from("bookings")
    .select("*")
    .order("check_in", { ascending: false });

  return NextResponse.json(data || []);
}
EOF

# ── app/api/admin/bookings/[id]/route.ts ──
cat > "app/api/admin/bookings/[id]/route.ts" << 'EOF'
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
EOF

# ── next.config.ts ──
cat > next.config.ts << 'EOF'
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  experimental: {},
};

export default nextConfig;
EOF

echo ""
echo "✅ All files created!"
echo ""
echo "Next steps:"
echo "  1. cp .env.local.example .env.local"
echo "  2. Fill in your keys in .env.local"
echo "  3. Add a hero image at public/hero.jpg"
echo "  4. npm run dev"
echo ""