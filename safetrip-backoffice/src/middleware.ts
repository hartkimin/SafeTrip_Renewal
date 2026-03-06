import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

/**
 * SafeTrip Backoffice Middleware
 * Handles route protection and authentication redirects.
 */
export function middleware(request: NextRequest) {
    const { pathname } = request.nextUrl;
    const token = request.cookies.get('admin_token')?.value;

    const isLoginPage = pathname === '/login';
    const isPublicAsset = pathname.startsWith('/_next') || 
                         pathname.startsWith('/api') || 
                         pathname.includes('favicon.ico') ||
                         pathname.includes('icon.svg');

    if (isPublicAsset) {
        return NextResponse.next();
    }

    // Redirect to login if not authenticated and trying to access protected route
    if (!token && !isLoginPage) {
        const url = request.nextUrl.clone();
        url.pathname = '/login';
        // Optional: add callback URL
        // url.searchParams.set('callbackUrl', pathname);
        return NextResponse.redirect(url);
    }

    // Redirect to dashboard if authenticated and trying to access login page
    if (token && isLoginPage) {
        const url = request.nextUrl.clone();
        url.pathname = '/';
        return NextResponse.redirect(url);
    }

    return NextResponse.next();
}

// See "Matching Paths" below to learn more
export const config = {
    matcher: [
        /*
         * Match all request paths except for the ones starting with:
         * - api (API routes)
         * - _next/static (static files)
         * - _next/image (image optimization files)
         * - favicon.ico (favicon file)
         */
        '/((?!api|_next/static|_next/image|favicon.ico).*)',
    ],
};
