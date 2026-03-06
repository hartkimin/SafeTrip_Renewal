/**
 * SafeTrip Backend API Endpoint Constants
 * Base: /api/v1 (safetrip-server-api NestJS)
 * 104 endpoints across 15 domains
 */

export const API = {
    // ─── Auth ───
    AUTH: {
        FIREBASE_VERIFY: '/auth/firebase-verify',
        LOGOUT: '/auth/logout',
        VERIFY: '/auth/verify',
        REGISTER: '/auth/register',
        CONSENT: '/auth/consent',
        ACCOUNT: '/auth/account',
        CANCEL_DELETION: '/auth/cancel-deletion',
    },

    // ─── Users ───
    USERS: {
        REGISTER: '/users/register',
        BY_PHONE: '/users/by-phone',
        SEARCH: '/users/search',
        ME: '/users/me',
        ME_LOCATION_SHARING: '/users/me/location-sharing',
        ME_DEVICE: '/users/me/device',
        ME_FCM_TOKEN: '/users/me/fcm-token',
        BY_ID: (userId) => `/users/${userId}`,
        FCM_TOKEN: (userId) => `/users/${userId}/fcm-token`,
        TERMS: (userId) => `/users/${userId}/terms`,
        // Admin
        ADMIN_LIST: '/users/admin/list',
        ADMIN_STATS: '/users/admin/stats',
        BAN: (userId) => `/users/${userId}/ban`,
    },

    // ─── Groups ───
    GROUPS: {
        LIST: '/groups',
        BY_ID: (groupId) => `/groups/${groupId}`,
        MY_PERMISSION: (groupId) => `/groups/${groupId}/my-permission`,
        RECENT: (userId) => `/groups/users/${userId}/recent-groups`,
        MEMBERS: (tripId) => `/groups/${tripId}/members`,
        MEMBER_ROLE: (tripId, userId) => `/groups/${tripId}/members/${userId}/role`,
        MEMBER: (tripId, userId) => `/groups/${tripId}/members/${userId}`,
        PREVIEW_BY_CODE: (code) => `/groups/preview-by-code/${code}`,
        JOIN_BY_CODE: (code) => `/groups/join-by-code/${code}`,
        INVITE_CODES: (groupId) => `/groups/${groupId}/invite-codes`,
        INVITE_CODE: (groupId, codeId) => `/groups/${groupId}/invite-codes/${codeId}`,
        TRANSFER_LEADERSHIP: (groupId) => `/groups/${groupId}/transfer-leadership`,
        TRANSFER_HISTORY: (groupId) => `/groups/${groupId}/transfer-history`,
    },

    // ─── Trips ───
    TRIPS: {
        LIST: '/trips',
        BY_ID: (tripId) => `/trips/${tripId}`,
        PREVIEW: (code) => `/trips/preview/${code}`,
        INVITE: (inviteCode) => `/trips/invite/${inviteCode}`,
        VERIFY_CODE: (code) => `/trips/verify-invite-code/${code}`,
        JOIN: '/trips/join',
        SCHEDULES: (tripId) => `/trips/${tripId}/schedules`,
        SCHEDULE_ITEMS: (tripId) => `/trips/${tripId}/schedules/items`,
        SEND_INVITE: (tripId) => `/trips/${tripId}/invite`,
        ACCEPT_INVITE: '/trips/invite/accept',
        // Admin
        ADMIN_LIST: '/trips/admin/list',
        ADMIN_STATS: '/trips/admin/stats',
    },

    // ─── Guardians ───
    GUARDIANS: {
        REQUEST: '/trips/guardian/request',
        APPROVAL_STATUS: '/trips/guardian/approval-status',
        LIST: (tripId) => `/trips/${tripId}/guardians`,
        RESPOND: (tripId, linkId) => `/trips/${tripId}/guardians/${linkId}/respond`,
        BY_LINK: (tripId, linkId) => `/trips/${tripId}/guardians/${linkId}`,
        ME: (tripId) => `/trips/${tripId}/guardians/me`,
        PENDING: (tripId) => `/trips/${tripId}/guardians/pending`,
        LINKED_MEMBERS: (tripId) => `/trips/${tripId}/guardians/linked-members`,
        LOCATION_REQUEST: (tripId, linkId) => `/trips/${tripId}/guardians/${linkId}/location-request`,
        LOCATION_REQUEST_BY_ID: (tripId, requestId) => `/trips/${tripId}/guardians/location-request/${requestId}`,
        SNAPSHOTS: (tripId, linkId) => `/trips/${tripId}/guardians/${linkId}/snapshots`,
    },

    // ─── Locations ───
    LOCATIONS: {
        BATCH: (tripId) => `/trips/${tripId}/locations/batch`,
        LIST: (tripId) => `/trips/${tripId}/locations`,
        LATEST: (tripId) => `/trips/${tripId}/locations/latest`,
        SHARING_SETTINGS: (tripId) => `/trips/${tripId}/locations/sharing-settings`,
        SCHEDULES: (tripId) => `/trips/${tripId}/locations/schedules`,
        STAY_POINTS: (tripId) => `/trips/${tripId}/locations/stay-points`,
    },

    // ─── Emergencies ───
    EMERGENCIES: {
        LIST: '/emergencies',
        STATS: '/emergencies/stats',
        BY_TRIP: (tripId) => `/emergencies/trip/${tripId}`,
        RESOLVE: (id) => `/emergencies/${id}/resolve`,
        ACKNOWLEDGE: (id) => `/emergencies/${id}/acknowledge`,
        CONTACTS: '/emergencies/contacts',
        CONTACT: (contactId) => `/emergencies/contacts/${contactId}`,
    },

    // ─── Chats ───
    CHATS: {
        ROOMS: (tripId) => `/chats/trip/${tripId}/rooms`,
        MESSAGES: (roomId) => `/chats/rooms/${roomId}/messages`,
        READ: (roomId) => `/chats/rooms/${roomId}/read`,
    },

    // ─── FCM / Notifications ───
    FCM: {
        SEND: '/fcm/send',
        SEND_MULTICAST: '/fcm/send-multicast',
        HISTORY: '/fcm/history',
        UNREAD_COUNT: '/fcm/history/unread-count',
        MARK_READ: (notificationId) => `/fcm/history/${notificationId}/read`,
    },

    // ─── Payments ───
    PAYMENTS: {
        CREATE: '/payments/transaction',
        VERIFY: (id) => `/payments/transaction/${id}/verify`,
        TRANSACTIONS: '/payments/transactions',
        SUBSCRIPTION: '/payments/subscription',
        // Admin
        ADMIN_TRANSACTIONS: '/payments/admin/transactions',
        ADMIN_STATS: '/payments/admin/stats',
    },

    // ─── B2B ───
    B2B: {
        ORGANIZATIONS: '/b2b/organizations',
        ORGANIZATION: (orgId) => `/b2b/organizations/${orgId}`,
        CONTRACTS: (orgId) => `/b2b/organizations/${orgId}/contracts`,
        ADMINS: (orgId) => `/b2b/organizations/${orgId}/admins`,
        DASHBOARD_CONFIG: (orgId) => `/b2b/organizations/${orgId}/dashboard-config`,
    },

    // ─── Countries ───
    COUNTRIES: {
        LIST: '/countries',
    },

    // ─── Guides ───
    GUIDES: {
        SEARCH: '/guides/search',
        BY_COUNTRY: (code) => `/guides/${code}`,
        EMERGENCY: (code) => `/guides/${code}/emergency`,
    },

    // ─── Events ───
    EVENTS: {
        LIST: '/events',
    },

    // ─── MOFA ───
    MOFA: {
        SUMMARY: (code) => `/mofa/country/${code}/summary`,
        SAFETY: (code) => `/mofa/country/${code}/safety`,
        ENTRY: (code) => `/mofa/country/${code}/entry`,
        MEDICAL: (code) => `/mofa/country/${code}/medical`,
        CONTACTS: (code) => `/mofa/country/${code}/contacts`,
    },
};
