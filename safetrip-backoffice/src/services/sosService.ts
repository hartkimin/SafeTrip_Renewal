import api from '@/lib/apiClient';
import { API } from '@/lib/apiEndpoints';

export interface EmergencyEvent {
    emergency_id: string;
    user_id: string;
    user_name: string;
    trip_id: string;
    status: 'active' | 'in_progress' | 'resolved';
    latitude: number;
    longitude: number;
    location?: string;
    battery_level?: number;
    network_type?: string;
    created_at: string;
    resolved_at?: string;
    description?: string;
}

export interface SOSStats {
    unresolved: number;
    inProgress: number;
    resolvedToday: number;
    avgResponseTime?: string;
}

/**
 * SOS / Emergency Service — Backoffice SOS center
 */
export const sosService = {
    /** List all emergencies (GET /emergencies) */
    getEmergencies: async (params = {}) => {
        return api.get(API.EMERGENCIES.LIST, params);
    },

    /** Get emergency statistics */
    getStats: async (): Promise<SOSStats> => {
        const res = await api.get(API.EMERGENCIES.STATS);
        return res?.data || res || { unresolved: 0, inProgress: 0, resolvedToday: 0 };
    },

    /** Get emergencies by trip (GET /emergencies/trip/:tripId) */
    getEmergenciesByTrip: async (tripId: string) => {
        return api.get(API.EMERGENCIES.BY_TRIP(tripId));
    },

    /** Resolve an emergency (PUT /emergencies/:id/resolve) */
    resolveEmergency: async (emergencyId: string, data: { resolved_by: string; notes?: string }) => {
        return api.put(API.EMERGENCIES.RESOLVE(emergencyId), data);
    },

    /** Acknowledge an emergency (PUT /emergencies/:id/acknowledge) */
    acknowledgeEmergency: async (emergencyId: string) => {
        return api.put(API.EMERGENCIES.ACKNOWLEDGE(emergencyId));
    },

    /** Get latest locations for a trip (GET /trips/:id/locations/latest) */
    getLatestLocations: async (tripId: string) => {
        return api.get(API.LOCATIONS.LATEST(tripId));
    },
};

export default sosService;
