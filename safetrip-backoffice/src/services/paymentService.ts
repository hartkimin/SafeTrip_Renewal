import api from '@/lib/apiClient';
import { API } from '@/lib/apiEndpoints';

/**
 * Payment Service — Backoffice billing & finance
 */
export const paymentService = {
    /** [Admin] List all payment transactions (GET /payments/admin/transactions) */
    async getTransactions(params = {}) {
        return api.get(API.PAYMENTS.ADMIN_TRANSACTIONS, params);
    },

    /** [Admin] Get payment statistics */
    async getPaymentStats() {
        return api.get(API.PAYMENTS.ADMIN_STATS);
    },

    /** Verify a transaction (POST /payments/transaction/:id/verify) */
    async verifyTransaction(transactionId) {
        return api.post(API.PAYMENTS.VERIFY(transactionId));
    },

    /** Get subscription info (GET /payments/subscription) */
    async getSubscription() {
        return api.get(API.PAYMENTS.SUBSCRIPTION);
    },

    /** Create a payment transaction (POST /payments/transaction) */
    async createTransaction(data) {
        return api.post(API.PAYMENTS.CREATE, data);
    },
};

export default paymentService;
