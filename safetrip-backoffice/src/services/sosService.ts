import api from '@/lib/apiClient';
import { API } from '@/lib/apiEndpoints';

/**
 * SOS / Emergency Service — Backoffice SOS center
 */
export const sosService = {
    /** List all emergencies (GET /emergencies) */
    async getEmergencies(params = {}) {
        return api.get(API.EMERGENCIES.LIST, params);
    },

    /** Get emergencies by trip (GET /emergencies/trip/:tripId) */
    async getEmergenciesByTrip(tripId) {
        return api.get(API.EMERGENCIES.BY_TRIP(tripId));
    },

    /** Resolve an emergency (PUT /emergencies/:id/resolve) */
    async resolveEmergency(emergencyId, data = {}) {
        return api.put(API.EMERGENCIES.RESOLVE(emergencyId), data);
    },

    /** Acknowledge an emergency (PUT /emergencies/:id/acknowledge) */
    async acknowledgeEmergency(emergencyId) {
        return api.put(API.EMERGENCIES.ACKNOWLEDGE(emergencyId));
    },

    /** Get latest locations for a trip (GET /trips/:id/locations/latest) */
    async getLatestLocations(tripId) {
        return api.get(API.LOCATIONS.LATEST(tripId));
    },

    /** Get emergency contacts (GET /emergencies/contacts) */
    async getEmergencyContacts() {
        return api.get(API.EMERGENCIES.CONTACTS);
    },
};

export default sosService;
