import type React from "react";
import type { Metadata } from "next";
import { ThemeProvider } from "@/components/theme/ThemeProvider";
import { ClientProviders } from "@/components/providers/ClientProviders";
import "./globals.css";

export const metadata: Metadata = {
  title: "Bytebot",
  description: "Bytebot is the container for desktop agents.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="font-sans antialiased">
        <ThemeProvider>
          <ClientProviders>{children}</ClientProviders>
        </ThemeProvider>
      </body>
    </html>
  );
}
