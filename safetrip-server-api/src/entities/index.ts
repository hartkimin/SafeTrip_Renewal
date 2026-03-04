// Central entity barrel file — re-exports all entities.
// User Domain (A)
export { User } from './user.entity';

// Group & Trip Domain (B)
export { Group } from './group.entity';
export { GroupMember } from './group-member.entity';
export { Trip } from './trip.entity';

// Guardian Domain (C)
export {
    Guardian,
    GuardianLink,
    GuardianPause,
    GuardianLocationRequest,
    GuardianSnapshot,
} from './guardian.entity';

// Geofence Domain (D)
export { Geofence, GeofenceEvent, GeofencePenalty } from './geofence.entity';

// Location Domain (E)
export {
    Location,
    LocationSharing,
    LocationSchedule,
    StayPoint,
    SessionMapImage,
    PlannedRoute,
    RouteDeviation,
} from './location.entity';

// Emergency Domain (F)
export {
    Emergency,
    EmergencyContact,
    SosEvent,
    NoResponseEvent,
} from './emergency.entity';

// Chat Domain (G)
export { ChatRoom, ChatMessage, ChatReadStatus } from './chat.entity';

// Notification Domain (H)
export {
    Notification,
    FcmToken,
    NotificationPreference,
} from './notification.entity';

// Payment Domain (I)
export { Payment, Subscription } from './payment.entity';

// B2B Domain (J)
export {
    B2bOrganization,
    B2bContract,
    B2bAdmin,
    B2bDashboardConfig,
} from './b2b.entity';

// Country/Safety Domain (K)
export {
    Country,
} from './country.entity';

// Event Log Domain (L)
export { EventLog } from './event-log.entity';

// AI Domain (O)
export { AiUsage } from './ai.entity';

// Schedule Domain (M)
export { Schedule } from './schedule.entity';
export { TravelSchedule } from './travel-schedule.entity';
export { InviteCode } from './invite-code.entity';
