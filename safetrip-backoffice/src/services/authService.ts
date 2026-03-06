import api from '@/lib/apiClient';
import { API } from '@/lib/apiEndpoints';
import { auth } from '@/lib/auth';

export const authService = {
    /**
     * Authenticate admin user
     */
    login: async (credentials: { email: string; password?: string; token?: string }) => {
        try {
            // In a real scenario, this calls the backend which verifies Firebase token or password
            // For now, we'll simulate or use the provided API if available
            const response = await api.post(API.AUTH.FIREBASE_VERIFY, {
                token: credentials.token,
                email: credentials.email
            }, { requireAuth: false });

            if (response.token) {
                auth.setToken(response.token);
                auth.setUser(response.user || { email: credentials.email, role: 'admin' });
            }

            return response;
        } catch (error) {
            console.error('[AuthService] Login failed:', error);
            throw error;
        }
    },

    /**
     * Simulation for development/bypass
     */
    devLogin: async (email: string) => {
        // Simulate a successful login for development
        const mockToken = 'mock-admin-token-' + Math.random().toString(36).substring(7);
        auth.setToken(mockToken);
        auth.setUser({ email, role: 'super_admin', name: 'Dev Admin' });
        return { success: true, token: mockToken };
    },

    /**
     * Log out current session
     */
    logout: async () => {
        try {
            await api.post(API.AUTH.LOGOUT).catch(() => {});
        } finally {
            auth.logout();
            window.location.href = '/login';
        }
    }
};
