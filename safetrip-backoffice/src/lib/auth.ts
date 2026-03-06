import Cookies from 'js-cookie';

/**
 * SafeTrip Admin Authentication Utility
 * Uses 'js-cookie' for client-side cookie management.
 */

const TOKEN_NAME = 'admin_token';
const REFRESH_TOKEN_NAME = 'admin_refresh_token';

export const auth = {
    /**
     * Store the auth token in a cookie.
     */
    setToken: (token: string, expires: number = 7) => {
        Cookies.set(TOKEN_NAME, token, {
            expires,
            secure: process.env.NODE_ENV === 'production',
            sameSite: 'lax',
        });
    },

    /**
     * Get the stored auth token.
     */
    getToken: (): string | undefined => {
        return Cookies.get(TOKEN_NAME);
    },

    /**
     * Store user profile info in a cookie (serialized).
     */
    setUser: (user: any) => {
        Cookies.set('admin_user', JSON.stringify(user), {
            expires: 7,
            secure: process.env.NODE_ENV === 'production',
        });
    },

    /**
     * Get user profile info.
     */
    getUser: (): any | null => {
        const user = Cookies.get('admin_user');
        try {
            return user ? JSON.parse(user) : null;
        } catch {
            return null;
        }
    },

    /**
     * Remove all auth cookies.
     */
    logout: () => {
        Cookies.remove(TOKEN_NAME);
        Cookies.remove(REFRESH_TOKEN_NAME);
        Cookies.remove('admin_user');
    },

    /**
     * Check if a user is authenticated (client-side only).
     */
    isAuthenticated: (): boolean => {
        return !!Cookies.get(TOKEN_NAME);
    }
};

export default auth;
