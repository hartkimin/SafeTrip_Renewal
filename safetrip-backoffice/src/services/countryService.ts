import api from '@/lib/apiClient';
import { API } from '@/lib/apiEndpoints';

/**
 * Country & MOFA Service — Backoffice settings/country management
 */
export const countryService = {
    /** List all countries (GET /countries) */
    async getCountries() {
        return api.get(API.COUNTRIES.LIST);
    },

    /** Get MOFA safety info for a country (GET /mofa/country/:code/safety) */
    async getCountrySafety(countryCode) {
        return api.get(API.MOFA.SAFETY(countryCode));
    },

    /** Get MOFA summary for a country (GET /mofa/country/:code/summary) */
    async getCountrySummary(countryCode) {
        return api.get(API.MOFA.SUMMARY(countryCode));
    },

    /** Get MOFA entry requirements (GET /mofa/country/:code/entry) */
    async getCountryEntry(countryCode) {
        return api.get(API.MOFA.ENTRY(countryCode));
    },

    /** Get MOFA medical info (GET /mofa/country/:code/medical) */
    async getCountryMedical(countryCode) {
        return api.get(API.MOFA.MEDICAL(countryCode));
    },

    /** Get MOFA contacts (GET /mofa/country/:code/contacts) */
    async getCountryContacts(countryCode) {
        return api.get(API.MOFA.CONTACTS(countryCode));
    },

    /** Get emergency numbers for a country (GET /guides/:code/emergency) */
    async getEmergencyNumbers(countryCode) {
        return api.get(API.GUIDES.EMERGENCY(countryCode));
    },

    /** Search travel guides (GET /guides/search) */
    async searchGuides(query) {
        return api.get(API.GUIDES.SEARCH, { q: query });
    },
};

export default countryService;
