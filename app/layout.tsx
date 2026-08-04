import type { Metadata, Viewport } from "next";

import "./globals.css";

export const metadata: Metadata = {
  title: "Snake/Shift — Web Snake Game",
  description:
    "A fast, focused Snake game built for keyboard and touch play in the browser.",
};

export const viewport: Viewport = {
  themeColor: "#f1eddf",
  colorScheme: "light",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
