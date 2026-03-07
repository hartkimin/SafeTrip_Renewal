import api from '@/lib/apiClient';
import { API } from '@/lib/apiEndpoints';

export interface Trip {
    trip_id: string;
    trip_name: string;
    destination: string;
    status: 'planning' | 'active' | 'completed';
    start_date: string;
    end_date: string;
    captain_id: string;
    member_count: number;
    created_at: string;
}

export interface TripStats {
    totalTrips: number;
    activeTrips: number;
    completedTrips: number;
    planningTrips: number;
}

/**
 * Trip Service — Backoffice trip & group management
 */
export const tripService = {
    /** [Admin] List all trips (GET /trips/admin/list) */
    getTrips: async (params = {}) => {
        return api.get(API.TRIPS.ADMIN_LIST, params);
    },

    /** [Admin] Get trip statistics */
    getTripStats: async (): Promise<TripStats> => {
        const res = await api.get(API.TRIPS.ADMIN_STATS);
        return res?.data || res || { totalTrips: 0, activeTrips: 0, completedTrips: 0, planningTrips: 0 };
    },

    /** Get trip by ID (GET /trips/:id) */
    getTripById: async (tripId: string) => {
        return api.get(API.TRIPS.BY_ID(tripId));
    },

    /** Get trip members (GET /groups/:tripId/members) */
    getTripMembers: async (tripId: string) => {
        return api.get(API.GROUPS.MEMBERS(tripId));
    },

    /** Get trip schedules (GET /trips/:id/schedules) */
    getTripSchedules: async (tripId: string) => {
        return api.get(API.TRIPS.SCHEDULES(tripId));
    },

    /** Get trip guardians (GET /trips/:id/guardians) */
    getTripGuardians: async (tripId: string) => {
        return api.get(API.GUARDIANS.LIST(tripId));
    },
};

export default tripService;
