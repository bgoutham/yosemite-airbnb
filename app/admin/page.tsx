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
