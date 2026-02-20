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
