// API 상수

export const API_BASE_URL = process.env.API_BASE_URL || 'https://api.safetrip.io/v1';

export const API_ENDPOINTS = {
  AUTH: {
    SEND_OTP: '/auth/send-otp',
    VERIFY_OTP: '/auth/verify-otp',
    REFRESH: '/auth/refresh',
    LOGOUT: '/auth/logout',
  },
  USERS: {
    ME: '/users/me',
    UPDATE: '/users/me',
  },
  TRIPS: {
    LIST: '/trips',
    CREATE: '/trips',
    GET: '/trips/:id',
    UPDATE: '/trips/:id',
    DELETE: '/trips/:id',
  },
  GROUPS: {
    LIST: '/groups',
    CREATE: '/groups',
    GET: '/groups/:id',
    UPDATE: '/groups/:id',
    DELETE: '/groups/:id',
  },
  SOS: {
    CREATE: '/sos',
    GET: '/sos/:id',
    LIST: '/sos',
  },
} as const;

