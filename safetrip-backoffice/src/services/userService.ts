import api from '@/lib/apiClient';
import { API } from '@/lib/apiEndpoints';

export interface User {
    user_id: string;
    display_name: string;
    phone_number: string;
    email?: string;
    status: 'active' | 'inactive' | 'banned';
    minor_status: 'minor' | 'adult';
    created_at: string;
    trip_count: number;
    last_login?: string;
}

export const userService = {
    /**
     * Get list of all users with optional filters
     */
    getUsers: async (params: { 
        search?: string; 
        status?: string; 
        page?: number; 
        limit?: number 
    } = {}) => {
        const response = await api.get(API.USERS.ADMIN_LIST, params);
        return response;
    },

    /**
     * Get user statistics for dashboard cards
     */
    getUserStats: async () => {
        const response = await api.get(API.USERS.ADMIN_STATS);
        return response;
    },

    /**
     * Get details of a specific user
     */
    getUserDetail: async (userId: string) => {
        const response = await api.get(API.USERS.BY_ID(userId));
        return response;
    },

    /**
     * Ban a user
     */
    banUser: async (userId: string, reason?: string) => {
        const response = await api.post(API.USERS.BAN(userId), { reason });
        return response;
    }
};
