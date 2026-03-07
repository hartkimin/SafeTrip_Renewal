'use client';

import { usePathname } from 'next/navigation';
import { Providers } from "@/components/Providers";
import { Toaster } from "@/components/ui/sonner";
import { AdminLayout } from '@/components/AdminShell';
import './globals.css';

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const isLoginPage = pathname === '/login';

  return (
    <html lang="ko" suppressHydrationWarning>
      <head>
        <title>SafeTrip Admin</title>
        <meta name="description" content="SafeTrip Backoffice Administration Platform" />
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet" />
      </head>
      <body className="antialiased font-sans">
        <Providers>
          {isLoginPage ? (
            <main>{children}</main>
          ) : (
            <AdminLayout>{children}</AdminLayout>
          )}
          <Toaster position="top-right" richColors closeButton />
        </Providers>
      </body>
    </html>
  );
}
