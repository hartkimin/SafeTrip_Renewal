import api from '@/lib/apiClient';
import { API } from '@/lib/apiEndpoints';

/**
 * Trip Service — Backoffice trip & group management
 */
export const tripService = {
    /** [Admin] List all trips (GET /trips/admin/list) */
    async getTrips(params = {}) {
        return api.get(API.TRIPS.ADMIN_LIST, params);
    },

    /** [Admin] Get trip statistics */
    async getTripStats() {
        return api.get(API.TRIPS.ADMIN_STATS);
    },

    /** Get trip by ID (GET /trips/:id) */
    async getTripById(tripId) {
        return api.get(API.TRIPS.BY_ID(tripId));
    },

    /** Get trip members (GET /groups/:tripId/members) */
    async getTripMembers(tripId) {
        return api.get(API.GROUPS.MEMBERS(tripId));
    },

    /** Get trip schedules (GET /trips/:id/schedules) */
    async getTripSchedules(tripId) {
        return api.get(API.TRIPS.SCHEDULES(tripId));
    },

    /** Get trip guardians (GET /trips/:id/guardians) */
    async getTripGuardians(tripId) {
        return api.get(API.GUARDIANS.LIST(tripId));
    },

    /** Get group detail (GET /groups/:id) */
    async getGroupById(groupId) {
        return api.get(API.GROUPS.BY_ID(groupId));
    },

    /** Get invite codes for a group (GET /groups/:id/invite-codes) */
    async getInviteCodes(groupId) {
        return api.get(API.GROUPS.INVITE_CODES(groupId));
    },

    /** Get leadership transfer history (GET /groups/:id/transfer-history) */
    async getTransferHistory(groupId) {
        return api.get(API.GROUPS.TRANSFER_HISTORY(groupId));
    },
};

export default tripService;
