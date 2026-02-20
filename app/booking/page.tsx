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
