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
