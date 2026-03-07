import api from '@/lib/apiClient';
import { API } from '@/lib/apiEndpoints';

export interface Transaction {
    payment_id: string;
    user_id: string;
    user_name: string;
    amount: number;
    currency: string;
    payment_method: string;
    status: 'completed' | 'pending' | 'failed' | 'refunded';
    created_at: string;
}

export interface PaymentStats {
    totalRevenue: number;
    transactionCount: number;
    completedCount: number;
    refundedCount: number;
}

/**
 * Payment Service — Backoffice billing & finance
 */
export const paymentService = {
    /** [Admin] List all payment transactions (GET /payments/admin/transactions) */
    getTransactions: async (params = {}) => {
        return api.get(API.PAYMENTS.ADMIN_TRANSACTIONS, params);
    },

    /** [Admin] Get payment statistics */
    getPaymentStats: async (): Promise<PaymentStats> => {
        const res = await api.get(API.PAYMENTS.ADMIN_STATS);
        return res?.data || res || { totalRevenue: 0, transactionCount: 0, completedCount: 0, refundedCount: 0 };
    },

    /** Verify a transaction (POST /payments/transaction/:id/verify) */
    verifyTransaction: async (transactionId: string) => {
        return api.post(API.PAYMENTS.VERIFY(transactionId));
    },

    /** Get subscription info (GET /payments/subscription) */
    getSubscription: async () => {
        return api.get(API.PAYMENTS.SUBSCRIPTION);
    },

    /** Create a payment transaction (POST /payments/transaction) */
    createTransaction: async (data: any) => {
        return api.post(API.PAYMENTS.CREATE, data);
    },
};

export default paymentService;
