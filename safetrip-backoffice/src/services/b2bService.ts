import api from '@/lib/apiClient';
import { API } from '@/lib/apiEndpoints';

/**
 * B2B Service — Backoffice B2B partner management
 */
export const b2bService = {
    /** List B2B organizations (GET /b2b/organizations) */
    async getOrganizations(params = {}) {
        return api.get(API.B2B.ORGANIZATIONS, params);
    },

    /** Get organization by ID (GET /b2b/organizations/:id) */
    async getOrganization(orgId) {
        return api.get(API.B2B.ORGANIZATION(orgId));
    },

    /** Get contracts for an organization (GET /b2b/organizations/:id/contracts) */
    async getContracts(orgId) {
        return api.get(API.B2B.CONTRACTS(orgId));
    },

    /** Get admins for an organization (GET /b2b/organizations/:id/admins) */
    async getAdmins(orgId) {
        return api.get(API.B2B.ADMINS(orgId));
    },

    /** Get dashboard config for an organization (GET /b2b/organizations/:id/dashboard-config) */
    async getDashboardConfig(orgId) {
        return api.get(API.B2B.DASHBOARD_CONFIG(orgId));
    },
};

export default b2bService;
