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
