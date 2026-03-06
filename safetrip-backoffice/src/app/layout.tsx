'use client';

import { usePathname } from 'next/navigation';
import { Providers } from "@/components/Providers";
import { Toaster } from "@/components/ui/sonner";
import { Sidebar, Topbar } from '@/components/AdminShell';
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
      <body className="antialiased font-sans">
        <Providers>
          {isLoginPage ? (
            <main>{children}</main>
          ) : (
            <div className="admin-container">
              <Sidebar />
              <div className="main-content">
                <Topbar />
                <div className="content-wrapper">
                  {children}
                </div>
              </div>
            </div>
          )}
          <Toaster position="top-right" richColors closeButton />
        </Providers>
      </body>
    </html>
  );
}
