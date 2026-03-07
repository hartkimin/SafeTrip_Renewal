import api from '@/lib/apiClient';
import { API } from '@/lib/apiEndpoints';

export interface B2BOrganization {
    org_id: string;
    name: string;
    type: 'travel_agency' | 'school' | 'corporate' | 'other';
    status: 'active' | 'inactive' | 'suspended';
    contact_email: string;
    contact_phone: string;
    contract_start: string;
    contract_end: string;
    created_at: string;
}

export interface B2BStats {
    totalPartners: number;
    activePartners: number;
    expiringSoon: number;
    totalRevenue: number;
}

/**
 * B2B Service — Backoffice B2B partner management
 */
export const b2bService = {
    /** List B2B organizations (GET /b2b/organizations) */
    getOrganizations: async (params = {}) => {
        return api.get(API.B2B.ORGANIZATIONS, params);
    },

    /** Get B2B statistics (GET /b2b/stats) */
    getStats: async () => {
        return api.get(API.B2B.STATS);
    },

    /** Get organization by ID (GET /b2b/organizations/:id) */
    getOrganization: async (orgId: string) => {
        return api.get(API.B2B.ORGANIZATION(orgId));
    },

    /** Get contracts for an organization (GET /b2b/organizations/:id/contracts) */
    getContracts: async (orgId: string) => {
        return api.get(API.B2B.CONTRACTS(orgId));
    },

    /** Get admins for an organization (GET /b2b/organizations/:id/admins) */
    getAdmins: async (orgId: string) => {
        return api.get(API.B2B.ADMINS(orgId));
    },
};

export default b2bService;
