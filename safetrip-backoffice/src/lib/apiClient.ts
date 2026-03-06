/**
 * SafeTrip Backoffice API Client
 * Wraps fetch() with base URL, auth headers, error handling, and retry logic.
 */

import { auth } from './auth';

const BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3001/api/v1';

class ApiError extends Error {
    public status: number;
    public data: any;

    constructor(status: number, message: string, data: any = null) {
        super(message);
        this.name = 'ApiError';
        this.status = status;
        this.data = data;
    }
}

interface RequestOptions {
    method?: string;
    body?: any;
    headers?: Record<string, string>;
    params?: Record<string, any> | null;
    requireAuth?: boolean;
    retries?: number;
}

/**
 * Core fetch wrapper with error handling and auth.
 */
async function request(endpoint: string, options: RequestOptions = {}) {
    const {
        method = 'GET',
        body = null,
        headers = {},
        params = null,
        requireAuth = true,
        retries = 1,
    } = options;

    // Build URL with query params
    let url = `${BASE_URL}${endpoint}`;
    if (params) {
        const searchParams = new URLSearchParams();
        Object.entries(params).forEach(([key, value]) => {
            if (value !== null && value !== undefined && value !== '') {
                searchParams.append(key, String(value));
            }
        });
        const qs = searchParams.toString();
        if (qs) url += `?${qs}`;
    }

    // Build headers
    const reqHeaders: Record<string, string> = {
        'Content-Type': 'application/json',
        ...headers,
    };

    if (requireAuth) {
        const token = auth.getToken();
        if (token) {
            // Use real Firebase token if available
            reqHeaders['Authorization'] = `Bearer ${token}`;
        } else {
            // Dev/Admin bypass: use x-test-bypass header when no token
            reqHeaders['x-test-bypass'] = 'true';
            reqHeaders['x-test-user-id'] = 'backoffice-admin';
        }
    }

    // Build fetch options
    const fetchOptions: RequestInit = {
        method,
        headers: reqHeaders,
    };

    if (body && method !== 'GET') {
        fetchOptions.body = JSON.stringify(body);
    }

    // Execute with retry for rate limits
    let lastError: any = null;
    for (let attempt = 0; attempt <= retries; attempt++) {
        try {
            const response = await fetch(url, fetchOptions);

            // Handle rate limiting (429)
            if (response.status === 429 && attempt < retries) {
                const retryAfter = response.headers.get('Retry-After') || '5';
                const waitMs = parseInt(retryAfter, 10) * 1000;
                await new Promise((resolve) => setTimeout(resolve, waitMs));
                continue;
            }

            // Parse response
            const data = await response.json().catch(() => null);

            if (!response.ok) {
                throw new ApiError(
                    response.status,
                    data?.error || data?.message || `HTTP ${response.status}`,
                    data
                );
            }

            return data;
        } catch (error) {
            if (error instanceof ApiError) {
                throw error;
            }
            lastError = error;

            // Network error — retry once
            if (attempt < retries) {
                await new Promise((resolve) => setTimeout(resolve, 1000));
                continue;
            }
        }
    }

    throw new ApiError(0, lastError?.message || 'Network error — server unreachable');
}

// ─── Convenience Methods ───

export const api = {
    get: (endpoint: string, params: any = null, options: RequestOptions = {}) =>
        request(endpoint, { method: 'GET', params, ...options }),

    post: (endpoint: string, body: any = null, options: RequestOptions = {}) =>
        request(endpoint, { method: 'POST', body, ...options }),

    put: (endpoint: string, body: any = null, options: RequestOptions = {}) =>
        request(endpoint, { method: 'PUT', body, ...options }),

    patch: (endpoint: string, body: any = null, options: RequestOptions = {}) =>
        request(endpoint, { method: 'PATCH', body, ...options }),

    delete: (endpoint: string, options: RequestOptions = {}) =>
        request(endpoint, { method: 'DELETE', ...options }),
};

export { ApiError };
export default api;